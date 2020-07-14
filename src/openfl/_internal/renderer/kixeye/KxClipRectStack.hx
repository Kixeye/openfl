package openfl._internal.renderer.kixeye;

import openfl.geom.Rectangle;
import openfl.geom.Matrix;

@:access(openfl.geom.Matrix)
@:access(openfl._internal.renderer.kixeye.KxRenderer)
class KxClipRectStack
{
	private var _renderer:KxRenderer;
	private var _rects:Array<KxRect> = [new KxRect()];
	private var _size:Int = 0;
	private var _current:Int = -1;

	public function new(renderer:KxRenderer)
	{
		_renderer = renderer;
	}

	public function top():Int
	{
		return _size - 1;
	}

	public function begin(x:Float, y:Float, w:Float, h:Float)
	{
		_size = 1;
		_current = -1;
		var rect = _rects[0];
		rect.set(x, y, w, h);
	}

	public function push(r:Rectangle, t:Matrix):Void
	{
		if (_rects.length <= _size)
		{
			_rects.push(new KxRect());
		}
		var rect:KxRect = _rects[_size];

		var m = Matrix.__pool.get();
		m.copyFrom(t);
		m.concat(_renderer.__worldTransform);
		rect.transform(r, m);
		Matrix.__pool.release(m);

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

	public function scissor(index:Int):Bool
	{
		if (_rects.length <= index || _rects[index].area() < 0)
		{
			return false;
		}
		if (_current != index)
		{
			var r = _rects[index];
			var h = _renderer._height;
			_renderer.gl.scissor(Std.int(r.x), Std.int(h - (r.y + r.h)), Std.int(r.w), Std.int(r.h));
			_current = index;
		}
		return true;
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
