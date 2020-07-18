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

	private var _transform:Matrix = new Matrix();

	public function new(renderer:KxRenderer)
	{
		_renderer = renderer;
	}

	public function dispose():Void
	{
		_renderer = null;
		_stack = null;
		_pool = null;
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

	public function begin(width:Float, height:Float)
	{
		_size = 1;
		_poolSize = 0;
		top().set(0, 0, width, height);
	}

	public function push(r:Rectangle, t:Matrix, wt:Matrix):Void
	{
		if (_stack.length <= _size)
		{
			_stack.push(new KxRect());
		}

		_transform.copyFrom(t);
		_transform.concat(wt);

		var rect:KxRect = _stack[_size++];
		rect.transform(r, _transform);
		rect.scale(_renderer.pixelRatio);
		rect.clip(top());
	}

	public function pop():Void
	{
		--_size;
	}

	public function scissor(rect:KxRect, height:Float, flip:Bool):Bool
	{
		if (rect.area() <= 0)
		{
			return false;
		}
		var x = Math.floor(rect.x);
		var y = flip ? Math.floor(height - rect.y - rect.h) : Math.floor(rect.y);
		var w = Math.ceil(rect.w);
		var h = Math.ceil(rect.h);
		_renderer.gl.scissor(x, y, w, h);

		return true;
	}

	public function intersects(vertices:Array<Float>):Bool
	{
		return top().intersects(vertices);
	}
}
