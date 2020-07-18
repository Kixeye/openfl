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
@:access(openfl.geom.ColorTransform)
@:access(openfl.display.Bitmap)
@:access(openfl.display.BitmapData)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.display.Stage)
@:access(openfl.text.TextField)
@:access(openfl._internal.renderer.canvas.CanvasRenderer)
@:access(openfl._internal.renderer.kixeye.KxTexture)
class KxBatchRenderer
{
	private static inline var MAX_VERTICES:Int = 4096; //32768;
	private static inline var MAX_INDICES:Int = 8192;
	private static var IDENTITY_COLOR_TRANSFORM = new ColorTransform();
	private static var QUAD_INDICES:Array<Int> = [0, 1, 2, 0, 2, 3];

	public var gl:WebGLRenderingContext;

	private var _renderer:KxRenderer;

	private var _width:Float;
	private var _height:Float;
	private var _viewMatrix:Matrix = new Matrix();
	private var _worldTransform:Matrix = new Matrix();
	private var _worldColorTransform:ColorTransform = new ColorTransform();
	private var _worldAlpha:Float = 1.0;

	private var _shader:KxShader;
	private var _viewUniform:UniformLocation;
	private var _maxTextureUnits:Int;
	private var _maskUnit:Int;
	private var _defaultTexture:KxTexture;
	private var _vertices:KxVertexBuffer;
	private var _vertexStride:Int = 0;

	private var _pos:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _uvs:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _muv:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0];
	private var _vertexCache:Array<Float> = null;
	private var _transform = new Matrix();
	private var _colorTransform = new ColorTransform();

	private var _commands:Array<Command> = [];
	private var _blendMode:BlendMode = NORMAL;

	private var _clipRects:KxClipRectStack;
	private var _masks:KxMaskStack;
	private var _tilemapRenderer:KxTilemapRenderer;

	private var _root:DisplayObject;
	private var _target:KxRenderTarget;

	public function new(renderer:KxRenderer)
	{
		gl = renderer.gl;

		_renderer = renderer;

		_vertices = new KxVertexBuffer(gl);
		_vertices.setAttributes(_renderer.batchAttributes);
		_vertexStride = _vertices.commit(MAX_VERTICES, MAX_INDICES);
		_vertexCache = [for (i in 0..._vertexStride * 4) 0.0];

		_clipRects = new KxClipRectStack(_renderer);
		_masks = new KxMaskStack(_renderer);
		_tilemapRenderer = new KxTilemapRenderer(this);
	}

	public function dispose():Void
	{
		_vertices.dispose();
		_vertices = null;
		_commands = null;
		_clipRects.dispose();
		_clipRects = null;
		_masks.dispose();
		_masks = null;
		_tilemapRenderer.dispose();
		_tilemapRenderer = null;
		_viewMatrix = null;
		_root = null;
		gl = null;
	}

	public function render(object:DisplayObject, target:KxRenderTarget):Void
	{
		_target = target;
		if (_target == null)
		{
			_width = _renderer.width;
			_height = _renderer.height;
			_viewMatrix.setTo(
				2 / _width, 0,
				0, -2 / _height,
				-1, 1
			);
		}
		else
		{
			_width = _target.width;
			_height = _target.height;
			_viewMatrix.setTo(
				2 / _width, 0,
				0, 2 / _height,
				-1, -1
			);
		}
		_root = object;
		_beginFrame();
		_renderRecursive(object);
		_endFrame();
	}

	private function _beginFrame():Void
	{
		_commands = [];
		_vertices.begin();
		_clipRects.begin(_width, _height);
		_masks.begin();
	}

	private function _endFrame():Void
	{
		_vertices.end();

		if (_target == null)
		{
			var w = Std.int(_width);
			var h = Std.int(_height);
			gl.bindFramebuffer(gl.FRAMEBUFFER, null);
			gl.viewport(0, 0, w, h);
			gl.scissor(0, 0, w, h);
			gl.clearColor(_renderer.stage.__colorSplit[0], _renderer.stage.__colorSplit[1], _renderer.stage.__colorSplit[2], 1);
			gl.clear(gl.COLOR_BUFFER_BIT);
		}
		else
		{
			_target.bind();
		}

		_renderer.batchShader.use();
		_renderer.batchShader.updateUniformMat3(_renderer.viewUniform, _viewMatrix.toArray());
		for (i in 0..._renderer.maxTextureUnits)
		{
			_renderer.defaultTexture.bind(i, false);
		}
		_vertices.enable();

		var drawCalls = 0;
		var quads = 0;
		var flip = _target == null;
		for (cmd in _commands)
		{
			if (_clipRects.scissor(cmd.rect, _height, flip))
			{
				_setBlendMode(cmd.blendMode);
				for (i in 0...cmd.textures.length)
				{
					var texture = cmd.textures[i];
					texture.bind(i, true);
				}
				_masks.bind(cmd.mask);
				_vertices.draw(cmd.offset, cmd.count);
				++drawCalls;
			}
		}
		//trace("draw calls: " + drawCalls + ", quads: " + Std.int(_vertices.getNumVertices() / 4));
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

		if (object.__mask != null)
		{
			object.cacheAsBitmap = true;
			_masks.push(object.__mask);
		}
		if (object.__scrollRect != null)
		{
			_clipRects.push(object.__scrollRect, object.__renderTransform, _worldTransform);
		}

		_renderObject(object);

		if (object.__children != null && (_root == object || object.__cacheBitmap == null))
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
		if (object.__type == SIMPLE_BUTTON)
		{
			var button:SimpleButton = cast object;
			if (button.__currentState != null)
			{
				_renderObject(button.__currentState);
			}
		}

		if (object.__type == TEXTFIELD)
		{
			CanvasTextField.render(cast object, _renderer.softwareRenderer, object.__worldTransform);
		}
		if (object.__graphics != null)
		{
			CanvasGraphics.render(object.__graphics, _renderer.softwareRenderer);
		}

		if (_root != object)
		{
			_renderer.updateCacheBitmap(object);
			if (object.__cacheBitmap != null)
			{
				_pushQuad(object, object.__renderTarget.texture, object.__cacheBitmap.__renderTransform);
				return;
			}
		}

		if (object.__graphics != null && object.__graphics.__visible && object.__graphics.__bitmap != null)
		{
			var texture = object.__graphics.__bitmap.getTexture(gl);
			texture.pixelScale = _renderer.pixelRatio;
			_pushQuad(object, texture, object.__graphics.__worldTransform);
		}
		else if (object.__type == BITMAP)
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

	private function _pushQuad(obj:DisplayObject, texture:KxTexture, transform:Matrix):Void
	{
		var alpha = obj.__worldAlpha;
		var blendMode = obj.__worldBlendMode;
		var colorTransform = obj.__worldColorTransform;
		var scale9Grid = obj.__worldScale9Grid;
		var width = texture._width;
		var height = texture._height;
		var pixelRatio = _renderer.pixelRatio;

		if (scale9Grid != null)
		{
			var uvWidth = 1.0;
			var uvHeight = 1.0;

			var vertexBufferWidth = obj.width;
			var vertexBufferHeight = obj.height;
			var vertexBufferScaleX = obj.scaleX / pixelRatio;
			var vertexBufferScaleY = obj.scaleY / pixelRatio;

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
				var uvOffsetU = (pixelRatio * 0.5) / vertexBufferWidth;
				var uvOffsetV = (pixelRatio * 0.5) / vertexBufferHeight;

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
		_transform.concat(_worldTransform);

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
		if (!_masks.intersects(_pos))
		{
			return;
		}
		texture = (texture != null && texture.valid) ? texture : _defaultTexture;

		var textureUnit:Int = -1;
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
			cmd = new Command(_masks.top(), _clipRects.cacheTop(), blendMode, texture, _vertices.getNumIndices(), 6);
			_commands.push(cmd);
		}
		else
		{
			cmd = tail;
			cmd.count += 6;
		}

		_masks.apply(texture, _pos, _uvs, _muv);

		_colorTransform.__copyFrom(colorTransform != null ? colorTransform : IDENTITY_COLOR_TRANSFORM);
		_colorTransform.__combine(_worldColorTransform);

		alpha *= _worldAlpha;
		var ct = _colorTransform;
		var alphaOffset = ct.alphaOffset * alpha;

		var j = 0;
		for (i in 0...4)
		{
			var k0 = i * 2;
			var k1 = k0 + 1;
			_vertexCache[j++] = _pos[k0];
			_vertexCache[j++] = _pos[k1];
			_vertexCache[j++] = _uvs[k0];
			_vertexCache[j++] = _uvs[k1];
			_vertexCache[j++] = _muv[k0];
			_vertexCache[j++] = _muv[k1];
			_vertexCache[j++] = ct.redMultiplier;
			_vertexCache[j++] = ct.greenMultiplier;
			_vertexCache[j++] = ct.blueMultiplier;
			_vertexCache[j++] = alpha;
			_vertexCache[j++] = ct.redOffset;
			_vertexCache[j++] = ct.greenOffset;
			_vertexCache[j++] = ct.blueOffset;
			_vertexCache[j++] = alphaOffset;
			_vertexCache[j++] = textureUnit;
		}
		_vertices.push(_vertexCache, QUAD_INDICES);
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

	public function new(mask:DisplayObject, rect:KxRect, blendMode:BlendMode, texture:KxTexture, offset:Int, count:Int)
	{
		this.mask = mask;
		this.rect = rect;
		this.blendMode = blendMode;
		this.textures = [ texture ];
		this.offset = offset;
		this.count = count;
	}
}
