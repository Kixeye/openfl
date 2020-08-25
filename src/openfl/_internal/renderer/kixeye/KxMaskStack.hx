package openfl._internal.renderer.kixeye;

import openfl.geom.Point;
import openfl.geom.Matrix;
import openfl.geom.ColorTransform;
import openfl.display.Bitmap;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl._internal.renderer.canvas.CanvasRenderer;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.backend.gl.WebGLRenderingContext;

@:access(openfl.geom.Matrix)
@:access(openfl.display.Bitmap)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.DisplayObjectContainer)
@:access(openfl.display.Graphics)
@:access(openfl._internal.renderer.kixeye.KxTexture)
@:access(openfl._internal.renderer.kixeye.KxRenderer)
class KxMaskStack
{
	private static var QUAD_INDICES:Array<Int> = [0, 1, 2, 0, 2, 3];
	private static var DEFAULT_MUV:Array<Float> = [ 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 ];

	public var vertices:Array<Float>;
	public var indices:Array<Int>;
	public var numVertices:Int;
	public var numIndices:Int;

	private var _indices:Array<Int>;

	private var _renderer:KxRenderer;
	private var _whiteTexture:KxTexture;
	private var _zeroMask:KxTexture;
	private var _stack:Array<DisplayObject> = [];
	private var _clipPoly = new KxClipPoly();
	private var _maskRect = new KxRect();

	public function new(renderer:KxRenderer)
	{
		_renderer = renderer;
		_whiteTexture = new KxTexture(_renderer, null);
		_whiteTexture.uploadWhite();

		_zeroMask = new KxTexture(_renderer, null);

		vertices = [for (i in 0..._renderer._vertexStride * 8) 0.0];
		_indices = [for (i in 0...18) 0];
	}

	public function top():DisplayObject
	{
		return _stack.length > 0 ? _stack[_stack.length - 1] : null;
	}

	public function intersects(pos:Array<Float>):Bool
	{
		var obj = top();
		if (obj == null)
		{
			return true;
		}
		return _clipPoly.intersects(pos);
	}

	public function clip(texture:KxTexture, unit:Int, ct:ColorTransform, alpha:Float, pos:Array<Float>, uv:Array<Float>):Void
	{
		var posRef:Array<Float>;
		var uvRef:Array<Float>;
		var muvRef:Array<Float>;
		var obj = top();
		if (obj == null)
		{
			posRef = pos;
			uvRef = uv;
			muvRef = DEFAULT_MUV;
			numVertices = 4;

			indices = QUAD_INDICES;
			numIndices = QUAD_INDICES.length;
		}
		else
		{
			numVertices = _clipPoly.clip(pos, uv);

			if (numVertices == 0)
			{
				return;
			}

			posRef = _clipPoly.output;
			uvRef = _clipPoly.uvout;
			muvRef = _clipPoly.muvout;

			var numTriangles = numVertices - 2;
			numIndices = numTriangles * 3;
			var i = 0;
			for (t in 0...numTriangles)
			{
				_indices[i++] = t + 1;
				_indices[i++] = t + 2;
				_indices[i++] = 0;
			}
			indices = _indices;
		}

		var alphaOffset = ct.alphaOffset * alpha;
		var j = 0;
		for (i in 0...numVertices)
		{
			var k0 = i * 2;
			var k1 = k0 + 1;
			vertices[j++] = posRef[k0];
			vertices[j++] = posRef[k1];
			vertices[j++] = uvRef[k0];
			vertices[j++] = uvRef[k1];
			vertices[j++] = muvRef[k0];
			vertices[j++] = muvRef[k1];
			vertices[j++] = ct.redMultiplier;
			vertices[j++] = ct.greenMultiplier;
			vertices[j++] = ct.blueMultiplier;
			vertices[j++] = alpha;
			vertices[j++] = ct.redOffset;
			vertices[j++] = ct.greenOffset;
			vertices[j++] = ct.blueOffset;
			vertices[j++] = alphaOffset;
			vertices[j++] = unit;
		}
	}

	public function bind(obj:DisplayObject):Void
	{
		if (obj == null)
		{
			_whiteTexture.bind(_renderer._maskUnit, false);
		}
		else
		{
			var texture = getTexture(obj);
			texture.bind(_renderer._maskUnit, false);
		}
	}

	public function begin():Void
	{
		_stack = [];
	}

	public function push(obj:DisplayObject):Void
	{
		var o = null;
		var texture = getTexture(obj);
		if (texture != null)
		{
			o = obj;
		}
		_stack.push(o);
		update();
	}

	public function pop():Void
	{
		_stack.pop();
		update();
	}

	private function getTexture(obj:DisplayObject):KxTexture
	{
		if (obj.__type == BITMAP)
		{
			var bmp:Bitmap = cast obj;
			return bmp.__bitmapData.getTexture(_renderer);
		}
		else if (obj.__type == DISPLAY_OBJECT_CONTAINER)
		{
			var container:DisplayObjectContainer = cast obj;
			if (container.__children.length == 1)
			{
				var child = container.__children[0];
				return getTexture(child);
			}
		}

		if (obj.__graphics != null)
		{
			if (obj.__graphics.__bitmap != null)
			{
				var texture = obj.__graphics.__bitmap.getTexture(_renderer);
				texture.pixelScale = _renderer._pixelRatio;
				return texture;
			}
			else
			{
				return _zeroMask;
			}
		}
		return null;
	}

	private function getTransform(obj:DisplayObject):Matrix
	{
		if (obj.__type == BITMAP)
		{
			return obj.__renderTransform;
		}
		else if (obj.__type == DISPLAY_OBJECT_CONTAINER)
		{
			var container:DisplayObjectContainer = cast obj;
			if (container.__children.length == 1)
			{
				var child = container.__children[0];
				return getTransform(child);
			}
		}
		return obj.__graphics.__worldTransform;
	}

	private function update():Void
	{
		var obj = top();
		if (obj != null)
		{
			var texture = getTexture(obj);
			if (texture == _zeroMask)
			{
				_maskRect.set(0, 0, 0, 0);
				_clipPoly.setRect(_maskRect, Matrix.__identity, 1.0);
			}
			else
			{
				var transform = getTransform(obj);
				var right:Float = texture._width;
				var bottom:Float = texture._height;
				var pixelRatio = _renderer._pixelRatio;
				_maskRect.set(0, 0, texture._width, texture._height);
				_clipPoly.setRect(_maskRect, transform, pixelRatio);
			}
		}
	}
}
