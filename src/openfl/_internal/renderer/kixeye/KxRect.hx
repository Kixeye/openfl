package openfl._internal.renderer.kixeye;

import openfl.geom.Matrix;
import openfl.geom.Rectangle;

@:access(openfl.geom.Matrix)
class KxRect
{
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;

	public function new()
	{
	}

	public function clone():KxRect
	{
		var r = new KxRect();
		r.copyFrom(this);
		return r;
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
		var right = r.right;
		var bottom = r.bottom;

		x = m.__transformX(r.x, r.y);
		y = m.__transformY(r.x, r.y);
		w = m.__transformX(right, bottom) - x;
		h = m.__transformY(right, bottom) - y;
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
		var right = x + w;
		var bottom = y + h;
		var clipRight = r.x + r.w;
		var clipBottom = r.y + r.h;
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
		if (right > clipRight)
		{
			w -= right - clipRight;
		}
		if (bottom > clipBottom)
		{
			h -= bottom - clipBottom;
		}
		if (w < 0)
		{
			w = 0;
		}
		if (h < 0)
		{
			h = 0;
		}
	}
}
