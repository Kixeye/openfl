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

	public function begin(x:Float, y:Float, w:Float, h:Float)
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
		rect.transform(r, t);
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

	public function valid(index:Int):Bool
	{
		return _rects[index].area() > 0;
	}

	public function scissor(index:Int, h:Float):Void
	{
		if (_current != index)
		{
			var r:KxRect = _rects[index];
			_gl.scissor(Std.int(r.x), Std.int(h - (r.y + r.h)), Std.int(r.w), Std.int(r.h));
			_current = index;
		}
	}

	public function intersects(vertices:Array<Float>):Bool
	{
		var rect = _rects[_size - 1];
		return rect.intersects(vertices);
	}
}

@:access(openfl.geom.Matrix)
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

	public function area():Float
	{
		return w * h;
	}

	public function transform(r:Rectangle, m:Matrix):Void
	{
		var right = r.x + r.width;
		var bottom = r.y + r.height;

		var tx0 = m.a * r.x + m.c * r.y;
		var tx1 = tx0;
		var ty0 = m.b * r.x + m.d * r.y;
		var ty1 = ty0;

		var tx = m.a * right + m.c * r.y;
		var ty = m.b * right + m.d * r.y;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * right + m.c * bottom;
		ty = m.b * right + m.d * bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		tx = m.a * r.x + m.c * bottom;
		ty = m.b * r.x + m.d * bottom;

		if (tx < tx0) tx0 = tx;
		if (ty < ty0) ty0 = ty;
		if (tx > tx1) tx1 = tx;
		if (ty > ty1) ty1 = ty;

		set(tx0 + m.tx, ty0 + m.ty, tx1 - tx0, ty1 - ty0);
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

	public function isPointInside(a:Float, b:Float):Bool
	{
		return a >= x && a <= x + w && b >= y && b <= y + h;
	}

	public function intersects(v:Array<Float>):Bool
	{
		if (x + w < v[0]) return false;
		if (y + h < v[1]) return false;
		if (x > v[4]) return false;
		if (y > v[5]) return false;
		return true;
	}

	public function clip(r:KxRect):Void
	{
		if (w <= 0 || h <= 0) return;

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
