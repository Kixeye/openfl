package openfl._internal.renderer.kixeye;

#if kixeye
import js.html.webgl.UniformLocation;
#end

import lime.math.Matrix3;
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
@:access(openfl.geom.Rectangle)
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
	private static inline var MAX_VERTICES:Int = 16384;
	private static inline var MAX_INDICES:Int = 24576;
	private static var IDENTITY_COLOR_TRANSFORM = new ColorTransform();

	public var gl:WebGLRenderingContext;

	private var _stage:Stage;

	private var _pixelRatio:Float;
	private var _softwareRenderer:CanvasRenderer;

	private var _width:Float;
	private var _height:Float;
	private var _viewMatrix:Matrix = new Matrix();

	private var _shader:KxShader;
	private var _viewUniform:UniformLocation;
	private var _maxTextureUnits:Int;
	private var _maskUnit:Int;
	private var _defaultTexture:KxTexture;
	private var _vertices:KxVertexBuffer;
	private var _vertexStride:Int = 0;

	private var _pos:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _uvs:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _transform = new Matrix();

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
		_softwareRenderer.__worldTransform = __worldTransform;
		_softwareRenderer.__worldColorTransform = __worldColorTransform;

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

		KxTexture.maxTextureSize = maxTextureSize;

		BitmapData.__renderer = this;
		BitmapData.__softwareRenderer = _softwareRenderer;

		// initial GL state
		gl.disable(gl.DEPTH_TEST);
		gl.disable(gl.STENCIL_TEST);
		gl.enable(gl.SCISSOR_TEST);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

		_defaultTexture = new KxTexture(this, null);
		_defaultTexture.uploadDefault();

		_vertices = new KxVertexBuffer(gl);
		_vertices.attribute("a_pos", 2, false);
		_vertices.attribute("a_uv", 4, false);
		_vertices.attribute("a_colorMult", 4, false);
		_vertices.attribute("a_colorOffset", 4, false);
		_vertices.attribute("a_textureId", 1, false);
		_vertexStride = _vertices.commit(MAX_VERTICES, MAX_INDICES);

		_shader = new KxShader(gl);
		_shader.compile(QuadShader.VERTEX, QuadShader.FRAGMENT);
		_shader.bindAttributes(_vertices);
		_shader.use();
		for (i in 0..._maxTextureUnits)
		{
			var uniform = _shader.getUniform("u_sampler" + i);
			gl.uniform1i(uniform, i);
			_defaultTexture.bind(i, false);
		}
		gl.uniform1i(_shader.getUniform("u_mask"), _maskUnit);
		_defaultTexture.bind(_maskUnit, false);
		_viewUniform = _shader.getUniform("u_view");

		_clipRects = new KxClipRectStack(this);
		_masks = new KxMaskStack(this);
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

		_viewMatrix.setTo(
			2 / _width,	0,
			0, -2 / _height,
			-1, 1
		);
	}

	private override function __render(object:IBitmapDrawable):Void
	{
		_beginFrame();
		_renderRecursive(cast object);
		_endFrame();
	}

	private function _beginFrame():Void
	{
		_commands = [];
		_vertices.begin();
		_clipRects.begin();
		_masks.begin();
		_nodesVisited = 0;
	}

	private function _endFrame():Void
	{
		_vertices.end();

		var w = Std.int(_width);
		var h = Std.int(_height);
		gl.viewport(0, 0, w, h);
		gl.scissor(0, 0, w, h);
		gl.clearColor(_stage.__colorSplit[0], _stage.__colorSplit[1], _stage.__colorSplit[2], 1);
		gl.clear(gl.COLOR_BUFFER_BIT);

		_shader.use();
		_shader.updateUniformMat3(_viewUniform, _viewMatrix.toArray());
		_vertices.enable();

		var drawCalls = 0;
		var quads = 0;
		for (cmd in _commands)
		{
			if (cmd.count > 0 && _clipRects.scissor(cmd.rect))
			{
				_setBlendMode(cmd.blendMode);
				for (i in 0...cmd.textures.length)
				{
					var texture = cmd.textures[i];
					texture.bind(i, false);
				}
				_masks.bind(cmd.mask);
				_vertices.draw(cmd.offset, cmd.count);
				++drawCalls;
			}
		}

		//trace("nodes: " + _nodesVisited + ", draw calls: " + drawCalls + ", quads: " + Std.int(_vertices.getNumVertices() / 4));
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

	private function _renderRecursive(object:DisplayObject):Void
	{
		if (!object.__renderable)
		{
			return;
		}

		if (object.__type == SIMPLE_BUTTON)
		{
			var button:SimpleButton = cast object;
			if (button.__currentState != null)
			{
				_renderRecursive(button.__currentState);
				return;
			}
		}

		if (object.__mask != null)
		{
			_drawMaskGraphics(object.__mask);
			_masks.push(object.__mask);
		}
		if (object.__scrollRect != null)
		{
			_clipRects.push(object.__scrollRect, object.__renderTransform);
		}

		_renderObject(object);

		if (object.__children != null)
		{
			for (child in object.__children)
			{
				_renderRecursive(child);
			}
		}

		if (object.__scrollRect != null)
		{
			_clipRects.pop();
		}
		if (object.__mask != null)
		{
			_masks.pop();
		}
	}

	private function _renderObject(object:DisplayObject):Void
	{
		++_nodesVisited;

		_drawCacheBitmap(object);

		if (object.__graphics != null && object.__graphics.__visible && object.__graphics.__bitmap != null)
		{
			var texture = object.__graphics.__bitmap.getTexture(this);
			texture.pixelScale = _pixelRatio;
			_pushQuad(object, texture, object.__graphics.__worldTransform);
		}
		if (object.__type == BITMAP)
		{
			var bmp:Bitmap = cast object;
			if (bmp.__bitmapData != null)
			{
				_pushQuad(bmp, bmp.__bitmapData.getTexture(this), bmp.__renderTransform);
			}
		}
		else if (object.__type == TILEMAP)
		{
			_tilemapRenderer.render(cast object);
		}
		else if (object.__type == VIDEO)
		{
			var video:Video = cast object;
			var texture = video.__getTexture(this);
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

	private function _drawMaskGraphics(object:DisplayObject)
	{
		if (object.__graphics != null)
		{
			CanvasGraphics.render(object.__graphics, _softwareRenderer);
		}
		if (object.__type == DISPLAY_OBJECT_CONTAINER)
		{
			var container:DisplayObjectContainer = cast object;
			for (child in container.__children)
			{
				_drawMaskGraphics(child);
			}
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

		_transform.copyFrom(transform);
		_transform.scale(_pixelRatio, _pixelRatio);

		_pos[0] = _transform.__transformX(x, y);
		_pos[1] = _transform.__transformY(x, y);
		_pos[2] = _transform.__transformX(r, y);
		_pos[3] = _transform.__transformY(r, y);
		_pos[4] = _transform.__transformX(r, b);
		_pos[5] = _transform.__transformY(r, b);
		_pos[6] = _transform.__transformX(x, b);
		_pos[7] = _transform.__transformY(x, b);
	}

	private function _useDefaultUvs():Void
	{
		_uvs[0] = 0;
		_uvs[1] = 0;
		_uvs[2] = 1;
		_uvs[3] = 0;
		_uvs[4] = 1;
		_uvs[5] = 1;
		_uvs[6] = 0;
		_uvs[7] = 1;
	}

	private function _setUvs(u:Float, v:Float, s:Float, t:Float):Void
	{
		_uvs[0] = u;
		_uvs[1] = v;
		_uvs[2] = s;
		_uvs[3] = v;
		_uvs[4] = s;
		_uvs[5] = t;
		_uvs[6] = u;
		_uvs[7] = t;
	}

	private function _setUs(u:Float, s:Float):Void
	{
		_uvs[0] = u;
		_uvs[2] = s;
		_uvs[4] = s;
		_uvs[6] = u;
	}

	private function _setVs(v:Float, t:Float):Void
	{
		_uvs[1] = v;
		_uvs[3] = v;
		_uvs[5] = t;
		_uvs[7] = t;
	}

	private function _push(texture:KxTexture, blendMode:BlendMode, alpha:Float, colorTransform:ColorTransform)
	{
		texture = (texture != null && texture.valid) ? texture : _defaultTexture;

		var unit:Int = -1;
		var cmd:Command = null;
		var tail:Command = _commands.length > 0 ? _commands[_commands.length - 1] : null;
		var newCommand:Bool = (tail == null || tail.blendMode != blendMode || tail.mask != _masks.top() || !tail.rect.equals(_clipRects.top()));

		if (!newCommand)
		{
			for (i in 0...tail.textures.length)
			{
				var t = tail.textures[i];
				if (t == texture)
				{
					unit = i;
					break;
				}
			}
			if (unit == -1 && tail.textures.length < _maxTextureUnits)
			{
				unit = tail.textures.length;
				tail.textures.push(texture);
			}
		}
		if (newCommand || unit == -1)
		{
			unit = 0;
			cmd = new Command(_masks.top(), _clipRects.cacheTop(), blendMode, texture, _vertices.getNumIndices());
			_commands.push(cmd);
		}
		else
		{
			cmd = tail;
		}

		var ct = colorTransform != null ? colorTransform : IDENTITY_COLOR_TRANSFORM;
		_masks.clip(texture, unit, ct, alpha, _pos, _uvs);
		if (_masks.numVertices > 0)
		{
			_vertices.push(_masks.vertices, _masks.numVertices * _vertexStride, _masks.indices, _masks.numIndices);
			cmd.count += _masks.numIndices;
		}
	}
}

private class Command
{
	public var mask:DisplayObject;
	public var rect:KxRect;
	public var blendMode:BlendMode;
	public var textures:Array<KxTexture>;
	public var offset:Int;
	public var count:Int;

	public function new(mask:DisplayObject, rect:KxRect, blendMode:BlendMode, texture:KxTexture, offset:Int)
	{
		this.mask = mask;
		this.rect = rect;
		this.blendMode = blendMode;
		this.textures = [ texture ];
		this.offset = offset;
		this.count = 0;
	}
}

private class QuadShader
{
	public static inline var VERTEX:String = '
		precision mediump float;

		uniform mat3 u_view;

		attribute vec2 a_pos;
		attribute vec4 a_uv;
		attribute vec4 a_colorMult;
		attribute vec4 a_colorOffset;
		attribute float a_textureId;

		varying vec4 v_uv;
		varying vec4 v_colorMult;
		varying vec4 v_colorOffset;
		varying float v_textureId;

		void main(void)
		{
			v_uv = a_uv;
			v_colorMult = a_colorMult;
			v_colorOffset = a_colorOffset / 255.0;
			v_textureId = a_textureId;

			vec3 p = vec3(a_pos, 1) * u_view;
			gl_Position = vec4(p, 1);
		}
	';

	public static inline var FRAGMENT:String = '
		precision mediump float;

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

		void main(void)
		{
			vec4 color;

			if (v_textureId == 0.0) color = texture2D(u_sampler0, v_uv.xy);
			else if (v_textureId == 1.0) color = texture2D(u_sampler1, v_uv.xy);
			else if (v_textureId == 2.0) color = texture2D(u_sampler2, v_uv.xy);
			else if (v_textureId == 3.0) color = texture2D(u_sampler3, v_uv.xy);
			else if (v_textureId == 4.0) color = texture2D(u_sampler4, v_uv.xy);
			else if (v_textureId == 5.0) color = texture2D(u_sampler5, v_uv.xy);
			else if (v_textureId == 6.0) color = texture2D(u_sampler6, v_uv.xy);
			else if (v_textureId == 7.0) color = texture2D(u_sampler7, v_uv.xy);
			else if (v_textureId == 8.0) color = texture2D(u_sampler8, v_uv.xy);
			else if (v_textureId == 9.0) color = texture2D(u_sampler9, v_uv.xy);
			else if (v_textureId == 10.0) color = texture2D(u_sampler10, v_uv.xy);
			else if (v_textureId == 11.0) color = texture2D(u_sampler11, v_uv.xy);
			else if (v_textureId == 12.0) color = texture2D(u_sampler12, v_uv.xy);
			else if (v_textureId == 13.0) color = texture2D(u_sampler13, v_uv.xy);
			else if (v_textureId == 14.0) color = texture2D(u_sampler14, v_uv.xy);

			vec4 mask = texture2D(u_mask, v_uv.zw);

			color.rgb /= color.a;
			color = clamp((color * v_colorMult) + v_colorOffset, 0.0, 1.0);
			gl_FragColor = vec4(color.rgb * color.a, color.a) * mask.a;
		}
	';
}
