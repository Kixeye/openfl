package openfl._internal.renderer.kixeye;

import js.html.webgl.UniformLocation;

import haxe.io.Int32Array;
import openfl._internal.backend.gl.WebGLRenderingContext;
import openfl._internal.backend.utils.Float32Array;
import openfl._internal.renderer.canvas.CanvasRenderer;
import openfl._internal.renderer.canvas.CanvasTextField;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.renderer.canvas.CanvasShape;
import openfl.display.BlendMode;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.DisplayObjectRenderer;
import openfl.display.IBitmapDrawable;
import openfl.display.Graphics;
import openfl.display.SimpleButton;
import openfl.display.Stage;
import openfl.display.Tilemap;
import openfl.text.TextField;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.media.Video;

@:access(openfl.geom.Matrix)
@:access(openfl.display.Bitmap)
@:access(openfl.display.BitmapData)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.display.Stage)
@:access(openfl.display.IBitmapDrawable)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.text.TextField)
@:access(openfl._internal.renderer.canvas.CanvasRenderer)
@:access(openfl._internal.renderer.kixeye.KxTexture)
class KxRenderer extends DisplayObjectRenderer
{
	private static inline var MAX_VERTICES:Int = 32768;
	private static inline var MAX_INDICES:Int = 49152;
	private static var IDENTITY_COLOR_TRANSFORM = new ColorTransform();
	private static var QUAD_INDICES:Array<Int> = [0, 1, 2, 0, 2, 3];
	private static var DEFAULT_UVS:Array<Float> = [0, 0, 1, 0, 1, 1, 0, 1];
	private static var DEFAULT_MASK_UVS:Array<Float> = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5];

	public var gl:WebGLRenderingContext;

	private var _stage:Stage;

	private var _pixelRatio:Float;
	private var _softwareRenderer:CanvasRenderer;

	private var _width:Float;
	private var _height:Float;
	private var _widthScaled:Float;
	private var _heightScaled:Float;

	private var _shader:KxShader;
	private var _viewUniform:UniformLocation;
	private var _maxTextureUnits:Int;
	private var _maskUnit:Int;
	private var _defaultTexture:KxTexture;
	private var _vertices:KxVertexBuffer;
	private var _vertexStride:Int = 0;

	private var _uvCache:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _maskUvCache:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _posCache:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _uvs:Array<Float> = DEFAULT_UVS;
	private var _maskUvs:Array<Float> = DEFAULT_MASK_UVS;
	private var _vertexCache:Array<Float> = null;

	private var _commands:Array<Command> = [];
	private var _blendMode:BlendMode = NORMAL;

	private var _clipRects:KxClipRectStack;
	private var _masks:KxMaskStack;
	private var _tilemapRenderer:KxTilemapRenderer;
	private var _filterRenderer:KxFilterRenderer;

	private var _nodesVisited:Int = 0;

	public function new(stage:Stage, pixelRatio:Float)
	{
		super();

		gl = stage.window.context.webgl;

		_stage = stage;
		_pixelRatio = pixelRatio;
		_softwareRenderer = new CanvasRenderer(null);
		_softwareRenderer.pixelRatio = pixelRatio;
		_softwareRenderer.__worldTransform = new Matrix();
		_softwareRenderer.__worldColorTransform = new ColorTransform();

		var glslVersion = gl.getParameter(gl.SHADING_LANGUAGE_VERSION);
		trace("Shading language version: " + glslVersion);

		_maxTextureUnits = Std.int(Math.min(16, gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)));
		_maskUnit = --_maxTextureUnits;

		var maxTextureSize:Int = gl.getParameter(gl.MAX_TEXTURE_SIZE);
		trace("Max texture size: " + maxTextureSize);
		if (Graphics.maxTextureWidth == null)
		{
			Graphics.maxTextureWidth = Graphics.maxTextureHeight = maxTextureSize;
		}

		BitmapData.__renderer = this;
		BitmapData.__softwareRenderer = _softwareRenderer;

		// initial GL state
		gl.disable(gl.DEPTH_TEST);
		gl.enable(gl.SCISSOR_TEST);
		gl.disable(gl.STENCIL_TEST);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
		gl.pixelStorei(gl.UNPACK_ALIGNMENT, 1);

		_defaultTexture = new KxTexture(gl, null);
		_defaultTexture.uploadDefault();

		_vertices = new KxVertexBuffer(gl);
		_vertices.attribute("a_pos", 2, false);
		_vertices.attribute("a_uv", 4, false);
		_vertices.attribute("a_colorMult", 4, false);
		_vertices.attribute("a_colorOffset", 4, false);
		_vertices.attribute("a_textureId", 1, false);
		_vertexStride = _vertices.commit(MAX_VERTICES, MAX_INDICES);
		_vertexCache = [for (i in 0..._vertexStride * 4) 0];

		_shader = new KxShader(gl);
		_shader.compile(QuadShader.VERTEX, QuadShader.FRAGMENT);
		_shader.bindAttributes(_vertices);
		_shader.use();
		for (i in 0..._maxTextureUnits)
		{
			gl.uniform1i(_shader.getUniform("u_sampler" + i), i);
			_defaultTexture.bind(i, false);
		}
		gl.uniform1i(_shader.getUniform("u_mask"), _maskUnit);
		_viewUniform = _shader.getUniform("u_view");

		_clipRects = new KxClipRectStack(gl);
		_masks = new KxMaskStack(gl);
		_tilemapRenderer = new KxTilemapRenderer(this);
		_filterRenderer = new KxFilterRenderer(gl);
	}

	private override function __dispose():Void
	{
		_shader.dispose();
		_shader = null;
		_vertices.dispose();
		_vertices = null;
		_commands = null;
		_softwareRenderer.__dispose();
		_softwareRenderer = null;
		_clipRects = null;
		_viewUniform = null;
		_defaultTexture.dispose();
		_defaultTexture = null;
		gl = null;
	}

	private override function __resize(width:Int, height:Int):Void
	{
		_width = width;
		_height = height;
		_widthScaled = _width * _pixelRatio;
		_heightScaled = _height * _pixelRatio;
	}

	private override function __render(object:IBitmapDrawable):Void
	{
		_beginFrame();
		_nodesVisited = 0;
		_renderRecursive(object);
		_endFrame();
	}

	private function _beginFrame():Void
	{
		_commands = [];
		_vertices.begin();
		_clipRects.init(0, 0, _widthScaled, _heightScaled);
	}

	private function _endFrame():Void
	{
		_vertices.end();

		gl.viewport(0, 0, Std.int(_widthScaled), Std.int(_heightScaled));
		gl.clearColor(_stage.__colorSplit[0], _stage.__colorSplit[1], _stage.__colorSplit[2], 1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		_shader.use();
		_shader.updateUniform2(_viewUniform, _width, _height);

		_vertices.enable();

		var drawCalls = 0;
		var quads = 0;
		for (cmd in _commands)
		{
			if (_clipRects.valid(cmd.clipRect))
			{
				_clipRects.scissor(cmd.clipRect, _heightScaled);
				_setBlendMode(cmd.blendMode);
				for (i in 0...cmd.textures.length)
				{
					var texture = cmd.textures[i];
					texture.bind(i, true);
				}
				_masks.bind(cmd.mask, _maskUnit);
				_vertices.draw(cmd.offset, cmd.count);
				++drawCalls;
			}
		}

		trace("nodes: " + _nodesVisited + ", draw calls: " + drawCalls + ", quads: " + Std.int(_vertices.getNumVertices() / 4));
		// var err = gl.getError();
		// if (err != gl.NO_ERROR)
		// {
		// 	var msg = "GL error " + err;
		// 	trace(msg);
		// }
	}

	private function _setBlendMode(blendMode:BlendMode):Void
	{
		if (_blendMode == blendMode)
		{
			return;
		}
		_blendMode = blendMode;
		switch (_blendMode)
		{
			case ADD: gl.blendFunc(gl.ONE, gl.ONE);
			case MULTIPLY: gl.blendFunc(gl.DST_COLOR, gl.ONE_MINUS_SRC_ALPHA);
			case SCREEN: gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_COLOR);
			default: gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
		}
	}

	private function _renderRecursive(drawable:IBitmapDrawable):Void
	{
		if (drawable == null)
		{
			return;
		}
		var object:DisplayObject = cast drawable;
		if (!object.__worldVisible || !object.__renderable || object.__worldAlpha <= 0.0)
		{
			return;
		}
		if (object.__scrollRect != null)
		{
			_clipRects.push(object.__scrollRect, object.__renderTransform);
		}
		else if (object.__mask != null)
		{
			_masks.push(object.__mask);
		}
		_renderObject(object);
		if (object.__type == DISPLAY_OBJECT_CONTAINER)
		{
			var container:DisplayObjectContainer = cast object;
			for (child in container.__children)
			{
				_renderRecursive(child);
			}
		}
		if (object.__scrollRect != null)
		{
			_clipRects.pop();
		}
		else if (object.__mask != null)
		{
			_masks.pop();
		}
	}

	private function _renderObject(object:DisplayObject):Void
	{
		++_nodesVisited;

		if (object.__type == SIMPLE_BUTTON)
		{
			var button:SimpleButton = cast object;
			if (button.__currentState != null)
			{
				_renderObject(button.__currentState);
			}
		}

		_drawCacheBitmap(object);

		if (object.__cacheBitmapData != null)
		{
			_pushQuad(object, object.__cacheBitmapData.getTexture(gl), object.__cacheBitmapMatrix);
		}
		if (object.__graphics != null && object.__graphics.__visible && object.__graphics.__bitmap != null)
		{
			_pushQuad(object, object.__graphics.__bitmap.getTexture(gl), object.__graphics.__worldTransform);
		}
		if (object.__type == BITMAP)
		{
			var bmp:Bitmap = cast object;
			if (bmp.__bitmapData != null)
			{
				_pushQuad(bmp, bmp.__bitmapData.getTexture(gl), bmp.__renderTransform);
			}
		}
		else if (object.__type == TILEMAP)
		{
			_tilemapRenderer.render(cast object);
		}
		else if (object.__type == VIDEO)
		{
			var video:Video = cast object;
			var texture = video.__getTexture(gl);
			if (texture != null)
			{
				_pushQuad(video, texture, video.__renderTransform);
			}
		}
	}

	private function _drawCacheBitmap(object:DisplayObject)
	{
		if (object.__type == TEXTFIELD)
		{
			CanvasTextField.render(cast object, _softwareRenderer, object.__worldTransform);
		}
		if (object.__graphics != null)
		{
			CanvasGraphics.render(object.__graphics, _softwareRenderer);
		}
		if (object.__filters != null)
		{
			_filterRenderer.render(object);
		}
	}

	private function _pushQuad(obj:DisplayObject, texture:KxTexture, transform:Matrix):Void
	{
		var alpha = obj.__worldAlpha;
		var blendMode = obj.__worldBlendMode;
		var colorTransform = obj.__worldColorTransform;
		var scale9Grid = obj.__worldScale9Grid;
		var width = texture._width;
		var height = texture._height;

		if (scale9Grid != null)
		{
			var uvWidth = 1.0;
			var uvHeight = 1.0;

			var vertexBufferWidth = obj.width;
			var vertexBufferHeight = obj.height;
			var vertexBufferScaleX = obj.scaleX / _pixelRatio;
			var vertexBufferScaleY = obj.scaleY / _pixelRatio;

			var centerX = scale9Grid.width;
			var centerY = scale9Grid.height;
			if (centerX != 0 && centerY != 0)
			{
				var left = scale9Grid.x;
				var top = scale9Grid.y;
				var right = vertexBufferWidth - centerX - left;
				var bottom = vertexBufferHeight - centerY - top;

				var uvLeft = left / vertexBufferWidth;
				var uvTop = top / vertexBufferHeight;
				var uvCenterX = scale9Grid.width / vertexBufferWidth;
				var uvCenterY = scale9Grid.height / vertexBufferHeight;
				var uvRight = right / width;
				var uvBottom = bottom / height;
				var uvOffsetU = (_pixelRatio * 0.5) / vertexBufferWidth;
				var uvOffsetV = (_pixelRatio * 0.5) / vertexBufferHeight;

				var renderedLeft = left / vertexBufferScaleX;
				var renderedTop = top / vertexBufferScaleY;
				var renderedRight = right / vertexBufferScaleX;
				var renderedBottom = bottom / vertexBufferScaleY;
				var renderedCenterX = (width - renderedLeft - renderedRight);
				var renderedCenterY = (height - renderedTop - renderedBottom);

				//  a         b          c         d
				// p  0 ——— 1    4 ——— 5    8 ——— 9
				//    |  /  |    |  /  |    |  /  |
				//    2 ——— 3    6 ——— 7   10 ——— 11
				// q
				//   12 ——— 13  16 ——— 18  20 ——— 21
				//    |  /  |    |  /  |    |  /  |
				//   14 ——— 15  17 ——— 19  22 ——— 23
				// r
				//   24 ——— 25  28 ——— 29  32 ——— 33
				//    |  /  |    |  /  |    |  /  |
				//   26 ——— 27  30 ——— 31  34 ——— 35
				// s

				var a = 0;
				var b = renderedLeft;
				var c = renderedLeft + renderedCenterX;
				var bc = renderedCenterX;
				var d = width;
				var cd = d - c;

				var p = 0;
				var q = renderedTop;
				var r = renderedTop + renderedCenterY;
				var qr = renderedCenterY;
				var s = height;
				var rs = s - r;

				_setVs(0, (uvHeight * uvTop) - uvOffsetV);
				_setVertices(transform, a, p, b, q);
				_setUs(0, (uvWidth * uvLeft) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, b, p, bc, q);
				_setUs((uvWidth * uvLeft) + uvOffsetU, (uvWidth * (uvLeft + uvCenterX)) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, c, p, cd, q);
				_setUs((uvWidth * (uvLeft + uvCenterX)) + uvOffsetU, uvWidth);
				_push(texture, blendMode, alpha, colorTransform);

				_setVs((uvHeight * uvTop) + uvOffsetV, (uvHeight * (uvTop + uvCenterY)) - uvOffsetV);
				_setVertices(transform, a, q, b, qr);
				_setUs(0, (uvWidth * uvLeft) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, b, q, bc, qr);
				_setUs((uvWidth * uvLeft) + uvOffsetU, (uvWidth * (uvLeft + uvCenterX)) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, c, q, cd, qr);
				_setUs((uvWidth * (uvLeft + uvCenterX)) + uvOffsetU, uvWidth);
				_push(texture, blendMode, alpha, colorTransform);

				_setVs((uvHeight * (uvTop + uvCenterY)) + uvOffsetV, uvHeight);
				_setVertices(transform, a, r, b, rs);
				_setUs(0, (uvWidth * uvLeft) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, b, r, bc, rs);
				_setUs((uvWidth * uvLeft) + uvOffsetU, (uvWidth * (uvLeft + uvCenterX)) - uvOffsetU);
				_push(texture, blendMode, alpha, colorTransform);

				_setVertices(transform, c, r, cd, rs);
				_setUs((uvWidth * (uvLeft + uvCenterX)) + uvOffsetU, uvWidth);
				_push(texture, blendMode, alpha, colorTransform);
			}
			else if (centerX == 0 && centerY != 0)
			{
				// TODO
				// 3 ——— 2
				// |  /  |
				// 1 ——— 0
				// |  /  |
				// 5 ——— 4
				// |  /  |
				// 7 ——— 6
			}
			else if (centerY == 0 && centerX != 0)
			{
				// TODO
				// 3 ——— 2 ——— 5 ——— 7
				// |  /  |  /  |  /  |
				// 1 ——— 0 ——— 4 ——— 6
			}
		}
		else
		{
			_setVertices(transform, 0, 0, width, height);
			_useDefaultUvs();
			_push(texture, blendMode, alpha, colorTransform);
		}
	}

	public function _setVertices(transform:Matrix, x:Float, y:Float, w:Float, h:Float):Void
	{
		var r = x + w;
		var b = y + h;

		_posCache[0] = transform.__transformX(x, y);
		_posCache[1] = transform.__transformY(x, y);
		_posCache[2] = transform.__transformX(r, y);
		_posCache[3] = transform.__transformY(r, y);
		_posCache[4] = transform.__transformX(r, b);
		_posCache[5] = transform.__transformY(r, b);
		_posCache[6] = transform.__transformX(x, b);
		_posCache[7] = transform.__transformY(x, b);
	}

	private function _useDefaultUvs():Void
	{
		_uvs = DEFAULT_UVS;
	}

	private function _setUvs(u:Float, v:Float, s:Float, t:Float):Void
	{
		_uvCache[0] = u;
		_uvCache[1] = v;

		_uvCache[2] = s;
		_uvCache[3] = v;

		_uvCache[4] = s;
		_uvCache[5] = t;

		_uvCache[6] = u;
		_uvCache[7] = t;

		_uvs = _uvCache;
	}

	private function _setUs(u:Float, s:Float):Void
	{
		_uvCache[0] = u;
		_uvCache[2] = s;
		_uvCache[4] = s;
		_uvCache[6] = u;

		_uvs = _uvCache;
	}

	private function _setVs(v:Float, t:Float):Void
	{
		_uvCache[1] = v;
		_uvCache[3] = v;
		_uvCache[5] = t;
		_uvCache[7] = t;

		_uvs = _uvCache;
	}

	private function _push(texture:KxTexture, blendMode:BlendMode, alpha:Float, colorTransform:ColorTransform)
	{
		// if (!_clipRects.intersects(_posCache))
		// {
		// 	return;
		// }
		texture = (texture != null && texture.valid) ? texture : _defaultTexture;

		var textureUnit = -1;
		var cmd:Command = null;
		var tail:Command = _commands.length > 0 ? _commands[_commands.length - 1] : null;
		var newCommand:Bool = (tail == null || tail.blendMode != blendMode || tail.clipRect != _clipRects.top() || tail.mask != _masks.top());

		if (!newCommand)
		{
			for (i in 0...tail.textures.length)
			{
				var t = tail.textures[i];
				if (t == texture)
				{
					textureUnit = i;
					break;
				}
			}
			if (textureUnit == -1 && tail.textures.length < _maxTextureUnits)
			{
				textureUnit = tail.textures.length;
				tail.textures.push(texture);
			}
		}
		if (newCommand || textureUnit == -1)
		{
			textureUnit = 0;
			cmd = new Command(_masks.top(), _clipRects.top(), blendMode, texture, _vertices.getNumIndices(), 6);
			_commands.push(cmd);
		}
		else
		{
			cmd = tail;
			cmd.count += 6;
		}

		var ct = colorTransform != null ? colorTransform : IDENTITY_COLOR_TRANSFORM;
		var alphaOffset = ct.alphaOffset * alpha;

		for (i in 0...4)
		{
			var j = i * _vertexStride;
			var k = i * 2;
			_vertexCache[j + 0 ] = _posCache[k];
			_vertexCache[j + 1 ] = _posCache[k + 1];
			_vertexCache[j + 2 ] = _uvs[k];
			_vertexCache[j + 3 ] = _uvs[k + 1];
			_vertexCache[j + 4 ] = _maskUvs[k];
			_vertexCache[j + 5 ] = _maskUvs[k + 1];
			_vertexCache[j + 6 ] = ct.redMultiplier;
			_vertexCache[j + 7 ] = ct.greenMultiplier;
			_vertexCache[j + 8 ] = ct.blueMultiplier;
			_vertexCache[j + 9 ] = alpha;
			_vertexCache[j + 10 ] = ct.redOffset;
			_vertexCache[j + 11 ] = ct.greenOffset;
			_vertexCache[j + 12] = ct.blueOffset;
			_vertexCache[j + 13] = alphaOffset;
			_vertexCache[j + 14] = textureUnit;
		}
		_vertices.push(_vertexCache, QUAD_INDICES);
	}
}

private class Command
{
	public var mask:Int;
	public var clipRect:Int;
	public var blendMode:BlendMode;
	public var textures:Array<KxTexture>;
	public var offset:Int;
	public var count:Int;

	public function new(mask:Int, clipRect:Int, blendMode:BlendMode, texture:KxTexture, offset:Int, count:Int)
	{
		this.mask = mask;
		this.clipRect = clipRect;
		this.blendMode = blendMode;
		this.textures = [ texture ];
		this.offset = offset;
		this.count = count;
	}
}

private class QuadShader
{
	public static inline var VERTEX:String = '
		precision highp float;

		uniform vec2 u_view;

		attribute vec2 a_pos;
		attribute vec4 a_uv;
		attribute vec4 a_colorMult;
		attribute vec4 a_colorOffset;
		attribute float a_textureId;

		varying vec4 v_uv;
		varying vec4 v_colorMult;
		varying vec4 v_colorOffset;
		varying float v_textureId;

		void main(void) {
			v_uv = a_uv;
			v_colorMult = a_colorMult;
			v_colorOffset = a_colorOffset / 255.0;
			v_textureId = a_textureId;

			vec2 p = (a_pos / u_view) * 2.0 - 1.0;
			p.y *= -1.0;
			gl_Position = vec4(p, 0, 1);
		}
	';

	public static inline var FRAGMENT:String = '
		precision highp float;

		varying vec4 v_uv;
		varying vec4 v_colorMult;
		varying vec4 v_colorOffset;
		varying float v_textureId;

		uniform sampler2D u_sampler0;
		uniform sampler2D u_sampler1;
		uniform sampler2D u_sampler2;
		uniform sampler2D u_sampler3;
		uniform sampler2D u_sampler4;
		uniform sampler2D u_sampler5;
		uniform sampler2D u_sampler6;
		uniform sampler2D u_sampler7;
		uniform sampler2D u_sampler8;
		uniform sampler2D u_sampler9;
		uniform sampler2D u_sampler10;
		uniform sampler2D u_sampler11;
		uniform sampler2D u_sampler12;
		uniform sampler2D u_sampler13;
		uniform sampler2D u_sampler14;

		uniform sampler2D u_mask;

		void main(void) {
			vec4 color;
			int textureId = int(v_textureId);

			vec2 uv = v_uv.xy;
			vec2 muv = v_uv.zw;

			if (textureId == 0) color = texture2D(u_sampler0, uv);
			else if (textureId == 1) color = texture2D(u_sampler1, uv);
			else if (textureId == 2) color = texture2D(u_sampler2, uv);
			else if (textureId == 3) color = texture2D(u_sampler3, uv);
			else if (textureId == 4) color = texture2D(u_sampler4, uv);
			else if (textureId == 5) color = texture2D(u_sampler5, uv);
			else if (textureId == 6) color = texture2D(u_sampler6, uv);
			else if (textureId == 7) color = texture2D(u_sampler7, uv);
			else if (textureId == 8) color = texture2D(u_sampler8, uv);
			else if (textureId == 9) color = texture2D(u_sampler9, uv);
			else if (textureId == 10) color = texture2D(u_sampler10, uv);
			else if (textureId == 11) color = texture2D(u_sampler11, uv);
			else if (textureId == 12) color = texture2D(u_sampler12, uv);
			else if (textureId == 13) color = texture2D(u_sampler13, uv);
			else if (textureId == 14) color = texture2D(u_sampler14, uv);

			vec4 mask = texture2D(u_mask, muv);

			color.rgb /= color.a;
			color = clamp((color * v_colorMult) + v_colorOffset, 0.0, 1.0);
			gl_FragColor = vec4(color.rgb * color.a, color.a) * mask.a;
		}
	';
}
