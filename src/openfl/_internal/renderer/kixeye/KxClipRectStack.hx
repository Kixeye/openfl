package openfl._internal.renderer.kixeye;

import openfl.geom.Rectangle;
import openfl.geom.Matrix;

@:access(openfl.geom.Matrix)
@:access(openfl._internal.renderer.kixeye.KxRenderer)
class KxClipRectStack
{
	private var _renderer:KxRenderer;
	private var _stack:Array<KxRect> = [new KxRect()];
	private var _size:Int;

	private var _pool:Array<KxRect> = [];
	private var _poolSize:Int = 0;

	public function new(renderer:KxRenderer)
	{
		_renderer = renderer;
	}

	public function top():KxRect
	{
		return _stack[_size - 1];
	}

	public function cacheTop():KxRect
	{
		if (_pool.length <= _poolSize)
		{
			_pool.push(new KxRect());
		}
		var rect:KxRect = _pool[_poolSize++];
		rect.copyFrom(top());
		return rect;
	}

	public function begin()
	{
		_size = 1;
		_poolSize = 0;
		top().set(0, 0, _renderer._width, _renderer._height);
	}

	public function push(r:Rectangle, t:Matrix):Void
	{
		if (_stack.length <= _size)
		{
			_stack.push(new KxRect());
		}
		var rect:KxRect = _stack[_size++];
		rect.transform(r, t);
		rect.scale(_renderer._pixelRatio);
		rect.clip(top());
	}

	public function pop():Void
	{
		--_size;
	}

	public function scissor(rect:KxRect):Bool
	{
		if (rect.area() <= 0)
		{
			return false;
		}
		var x = Math.floor(rect.x);
		var y = Math.floor(_renderer._height - rect.y - rect.h);
		var w = Math.floor(rect.w);
		var h = Math.floor(rect.h);
		_renderer.gl.scissor(x, y, w, h);

		return true;
	}

	public function intersects(vertices:Array<Float>):Bool
	{
		return top().intersects(vertices);
	}
}
