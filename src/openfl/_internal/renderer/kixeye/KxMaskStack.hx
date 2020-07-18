package openfl._internal.renderer.kixeye;

import openfl.geom.Point;
import openfl.geom.Matrix;
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
	private var _renderer:KxRenderer;
	private var _stack:Array<DisplayObject> = [];
	private var _maskRect = new KxRect();
	private var _objRect = new KxRect();
	private var _pixelSize = new Point();

	public function new(renderer:KxRenderer)
	{
		_renderer = renderer;
	}

	public function dispose():Void
	{
		_renderer = null;
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
		return _maskRect.intersects(pos);
	}

	public function apply(texture:KxTexture, pos:Array<Float>, uv:Array<Float>, muv:Array<Float>):Void
	{
		var obj = top();
		if (obj == null)
		{
			muv[0] = 0.5;
			muv[1] = 0.5;
			muv[2] = 0.5;
			muv[3] = 0.5;
			muv[4] = 0.5;
			muv[5] = 0.5;
			muv[6] = 0.5;
			muv[7] = 0.5;
		}
		else
		{
			var pixelRatio = _renderer.pixelRatio;

			var l = pos[0]; //Math.min(pos[0], pos[2]);
			var r = pos[2]; //Math.max(pos[0], pos[2]);
			var t = pos[1]; //Math.min(pos[1], pos[5]);
			var b = pos[5]; //Math.max(pos[1], pos[5]);

			_objRect.set(l, t, r - l, b - t);

			var ipx = (1.0 / texture._width) * (texture.pixelScale / pixelRatio);
			var ipy = (1.0 / texture._height) * (texture.pixelScale / pixelRatio);

			_objRect.clip(_maskRect);

			var objRight = _objRect.x + _objRect.w;
			var objBottom = _objRect.y + _objRect.h;

			var ld = (_objRect.x - pos[0]) * ipx;
			var td = (_objRect.y - pos[1]) * ipy;
			var rd = (pos[4] - objRight) * ipx;
			var bd = (pos[5] - objBottom) * ipy;

			pos[0] = _objRect.x;
			pos[1] = _objRect.y;

			pos[2] = objRight;
			pos[3] = _objRect.y;

			pos[4] = objRight;
			pos[5] = objBottom;

			pos[6] = _objRect.x;
			pos[7] = objBottom;

			uv[0] += ld;
			uv[1] += td;
			uv[2] -= rd;
			uv[3] += td;
			uv[4] -= rd;
			uv[5] -= bd;
			uv[6] += ld;
			uv[7] -= bd;

			var maskRight = _maskRect.x + _maskRect.w;
			var maskBottom = _maskRect.y + _maskRect.h;

			var ml = (_objRect.x - _maskRect.x) * _pixelSize.x;
			var mt = (_objRect.y - _maskRect.y) * _pixelSize.y;
			var mr = 1.0 - ((maskRight - objRight) * _pixelSize.x);
			var mb = 1.0 - ((maskBottom - objBottom) * _pixelSize.y);

			muv[0] = ml;
			muv[1] = mt;
			muv[2] = mr;
			muv[3] = mt;
			muv[4] = mr;
			muv[5] = mb;
			muv[6] = ml;
			muv[7] = mb;
		}
	}

	public function bind(obj:DisplayObject):Void
	{
		if (obj == null)
		{
			_renderer.whiteTexture.bind(_renderer.maskUnit, false);
		}
		else
		{

			obj.__renderTarget.texture.bind(_renderer.maskUnit, true);
		}
	}

	public function begin():Void
	{
		_stack = [];
	}

	public function push(obj:DisplayObject):Void
	{
		obj.cacheAsBitmap = true;
		_renderer.updateCacheBitmap(obj);
		if (obj.__renderTarget != null)
		{
			_stack.push(obj);
			update();
		}
	}

	public function pop():Void
	{
		_stack.pop();
		update();
	}

	private function update():Void
	{
		var obj = top();
		if (obj != null)
		{
			var pixelRatio = _renderer.pixelRatio;
			var texture = obj.__renderTarget.texture;
			var transform = obj.__cacheBitmap.__renderTransform;
			var right:Float = texture._width;
			var bottom:Float = texture._height;
			var x = transform.__transformX(0, 0);
			var y = transform.__transformY(0, 0);
			var w = transform.__transformX(right, bottom) - x;
			var h = transform.__transformY(right, bottom) - y;
			_maskRect.set(x, y, w, h);
			_maskRect.scale(pixelRatio);
			_pixelSize.setTo((1.0 / right) * (texture.pixelScale / pixelRatio), (1.0 / bottom) * (texture.pixelScale / pixelRatio));
		}
	}
}
