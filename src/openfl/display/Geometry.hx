package openfl.display;

#if kixeye
import openfl.display._internal.kixeye.KxVertexBuffer;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

/**
	Kixeye: a display object made of coloured triangles, drawn directly by
	KxRenderer. Add vertices with `pushVertex()`, three per triangle.
**/
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
class Geometry extends DisplayObject
{
	public static inline var FLOATS_PER_VERTEX = 2 + 4;

	private var __numVertices:Int = 0;
	private var __vertices:Array<Float> = [];
	private var __vertexBuffer:KxVertexBuffer = null;

	private var __bounds:Rectangle = new Rectangle(0, 0, 0, 0);

	public function new()
	{
		super();
		__drawableType = GEOMETRY;
		__blendMode = NORMAL;
	}

	public function clear():Void
	{
		__vertices = [];
		__numVertices = 0;
		__bounds.width = 0;
		__bounds.height = 0;
		__bounds.x = 0;
		__bounds.y = 0;

		if (__vertexBuffer != null)
		{
			__vertexBuffer.dispose();
			__vertexBuffer = null;
		}
	}

	public function pushVertex(x:Float, y:Float, color:Int, alpha:Float = 1.0)
	{
		__vertices.push(x);
		__vertices.push(y);
		__vertices.push(((color >> 16) & 0xFF) / 255);
		__vertices.push(((color >> 8) & 0xFF) / 255);
		__vertices.push((color & 0xFF) / 255);
		__vertices.push(alpha);

		__addPointToBounds(x, y);

		++__numVertices;
	}

	@:noCompletion private override function __getBounds(rect:Rectangle, matrix:Matrix):Void
	{
		var bounds = Rectangle.__pool.get();
		__bounds.__transform(bounds, matrix);
		rect.__expand(bounds.x, bounds.y, bounds.width, bounds.height);
		Rectangle.__pool.release(bounds);
	}

	private function __addPointToBounds(x:Float, y:Float):Void
	{
		if (x < __bounds.x)
		{
			__bounds.width += __bounds.x - x;
			__bounds.x = x;
		}

		if (y < __bounds.y)
		{
			__bounds.height += __bounds.y - y;
			__bounds.y = y;
		}

		if (x > __bounds.x + __bounds.width)
		{
			__bounds.width = x - __bounds.x;
		}

		if (y > __bounds.y + __bounds.height)
		{
			__bounds.height = y - __bounds.y;
		}
	}
}
#end
