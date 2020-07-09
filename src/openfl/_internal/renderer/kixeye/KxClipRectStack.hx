package openfl._internal.renderer.kixeye;

import openfl._internal.backend.gl.WebGLRenderingContext;
import openfl.geom.Rectangle;
import openfl.geom.Matrix;

class KxClipRectStack
{
	private var _gl:WebGLRenderingContext;
	private var _rects:Array<KxRect> = [new KxRect()];
	private var _size:Int = 0;
	private var _current:Int = -1;

	public function new(gl:WebGLRenderingContext)
	{
		_gl = gl;
	}

	public function top():Int
	{
		return _size - 1;
	}

	public function init(x:Float, y:Float, w:Float, h:Float)
	{
		_size = 1;
		_current = -1;
		_rects[0].set(x, y, w, h);
	}

	public function push(r:Rectangle, t:Matrix):Void
	{
		if (_rects.length <= _size)
		{
			_rects.push(new KxRect());
		}
		var rect:KxRect = _rects[_size];
		rect.setTransform(r, t);
		if (_size > 0)
		{
			rect.clip(_rects[_size - 1]);
		}
		++_size;
	}

	public function pop():Void
	{
		--_size;
	}

	public function scissor(index:Int):Void
	{
		if (_current != index)
		{
			var r:KxRect = _rects[index];
			if (r.w > 0 && r.h > 0)
			{
				var y = _rects[0].h - (r.y + r.h);
				_gl.scissor(Std.int(r.x), Std.int(y), Std.int(r.w), Std.int(r.h));
				_current = index;
			}
		}
	}
}


private class KxRect
{
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;

	public function new()
	{
	}

	public function set(x:Float, y:Float, w:Float, h:Float):Void
	{
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
	}

	public function scale(s:Float):Void
	{
		x *= s;
		y *= s;
		w *= s;
		h *= s;
	}

	public function setTransform(r:Rectangle, t:Matrix):Void
	{
		var right = r.x + r.width;
		var bottom = r.y + r.height;

		var tx0 = t.a * r.x + t.c * r.y;
		var tx1 = tx0;
		var ty0 = t.b * r.x + t.d * r.y;
		var ty1 = ty0;

		var tx = t.a * right + t.c * r.y;
		var ty = t.b * right + t.d * r.y;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = t.a * right + t.c * bottom;
		ty = t.b * right + t.d * bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = t.a * r.x + t.c * bottom;
		ty = t.b * r.x + t.d * bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		set(tx0 + t.tx, ty0 + t.ty, tx1 - tx0, ty1 - ty0);
	}

	public function copyFrom(r:KxRect):Void
	{
		x = r.x;
		y = r.y;
		w = r.w;
		h = r.h;
	}

	public function equals(r:KxRect):Bool
	{
		return x == r.x && y == r.y && w == r.w && h == r.h;
	}

	public function clip(r:KxRect):Void
	{
		if (x < r.x)
		{
			w -= r.x - x;
			x = r.x;
		}
		if (y < r.y)
		{
			h -= r.y - y;
			y = r.y;
		}
		if (x + w > r.x + r.w)
		{
			w -= (x + w) - (r.x + r.w);
		}
		if (y + h > r.y + r.h)
		{
			h -= (y + h) - (r.y + r.h);
		}
	}
}
