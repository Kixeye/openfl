package openfl._internal.renderer.kixeye;

import openfl.geom.Point;
import openfl.geom.Matrix;

@:access(openfl.geom.Matrix)
class KxClipPoly
{
	public var output:Array<Float>;
	public var uvout:Array<Float>;
	public var muvout:Array<Float>;
	public var numVerts:Int;

	private var _input:Array<Float>;
	private var _uvin:Array<Float>;
	private var _verts:Int;

	private var _points:Array<Float>;
	private var _tmp:Array<Float> = [0, 0];

	public function new()
	{
		_points = [for (i in 0...8) 0.0];
		output = [for (i in 0...16) 0.0];
		uvout = [for (i in 0...16) 0.0];
		muvout = [for (i in 0...16) 0.0];
		_input = [for (i in 0...16) 0.0];
		_uvin = [for (i in 0...16) 0.0];
	}

	public function setRect(rect:KxRect, transform:Matrix, scale:Float):Void
	{
		var right = rect.x + rect.w;
		var bottom = rect.y + rect.h;

		_points[0] = transform.__transformX(rect.x, rect.y) * scale;
		_points[1] = transform.__transformY(rect.x, rect.y) * scale;
		_points[2] = transform.__transformX(right, rect.y) * scale;
		_points[3] = transform.__transformY(right, rect.y) * scale;
		_points[4] = transform.__transformX(right, bottom) * scale;
		_points[5] = transform.__transformY(right, bottom) * scale;
		_points[6] = transform.__transformX(rect.x, bottom) * scale;
		_points[7] = transform.__transformY(rect.x, bottom) * scale;
	}

	public function intersects(pos:Array<Float>):Bool
	{
		for (i in 0...4)
		{
			var a = i * 2;
			var b = (a + 2) % 8;
			var ax = _points[a];
			var ay = _points[a + 1];
			var bx = _points[b];
			var by = _points[b + 1];

			var inside = true;
			for (j in 0...4)
			{
				var p = j * 2;
				var px = pos[j];
				var py = pos[j + 1];
				if (!_inside(px, py, ax, ay, bx, by))
				{
					inside = false;
					break;
				}
			}
			if (inside)
			{
				return true;
			}
		}
		return false;
	}

	public function clip(pos:Array<Float>, uv:Array<Float>):Int
	{
		numVerts = 4;
		for (i in 0...8)
		{
			output[i] = pos[i];
			uvout[i] = uv[i];
		}

		for (i in 0...4)
		{
			var a = i * 2;
			var b = (a + 2) % 8;
			var ax = _points[a];
			var ay = _points[a + 1];
			var bx = _points[b];
			var by = _points[b + 1];

			for (j in 0...numVerts * 2)
			{
				_input[j] = output[j];
				_uvin[j] = uvout[j];
			}
			_verts = 0;

			for (j in 0...numVerts)
			{
				var s = j * 2;
				var e = (s + 2) % (numVerts * 2);
				var sx = _input[s];
				var sy = _input[s + 1];
				var su = _uvin[s];
				var sv = _uvin[s + 1];
				var ex = _input[e];
				var ey = _input[e + 1];
				var eu = _uvin[e];
				var ev = _uvin[e + 1];

				var insideS = _inside(sx, sy, ax, ay, bx, by);
				var insideE = _inside(ex, ey, ax, ay, bx, by);
				if (insideS && insideE)
				{
					_push(ex, ey, eu, ev);
				}
				else if (!insideS && insideE)
				{
					_intersection(_tmp, ax, ay, bx, by, sx, sy, ex, ey);
					var dx = ex - sx;
					var dy = ey - sy;
					var ndx = _tmp[0] - sx;
					var ndy = _tmp[1] - sy;
					var d = Math.sqrt(dx * dx + dy * dy);
					var f = d > 0 ? Math.sqrt(ndx * ndx + ndy * ndy) / d : 0;
					var u = su + (eu - su) * f;
					var v = sv + (ev - sv) * f;
					_push(_tmp[0], _tmp[1], u, v);
					_push(ex, ey, eu, ev);
				}
				else if (insideS && !insideE)
				{
					_intersection(_tmp, ax, ay, bx, by, sx, sy, ex, ey);
					var dx = ex - sx;
					var dy = ey - sy;
					var ndx = _tmp[0] - sx;
					var ndy = _tmp[1] - sy;
					var d = Math.sqrt(dx * dx + dy * dy);
					var f = d > 0 ? Math.sqrt(ndx * ndx + ndy * ndy) / d : 0;
					var u = su + (eu - su) * f;
					var v = sv + (ev - sv) * f;
					_push(_tmp[0], _tmp[1], u, v);
				}
			}
			numVerts = _verts;
		}

		_project();

		// trace("numVerts: " + numVerts);
		// var s = "";
		// for (i in 0...numVerts)
		// {
		// 	var j = i * 2;
		// 	var x = output[j];
		// 	var y = output[j + 1];
		// 	s += "(" + x + ", " + y + ")";
		// }
		// trace("mask: " + _points);
		// trace("input: " + pos);
		// trace("output: [ " + s + "]");

		return numVerts;
	}

	private function _project():Void
	{
		var x1 = _points[0];
		var y1 = _points[1];
		var x2 = _points[2];
		var y2 = _points[3];
		var a1 = y1 - y2;
		var b1 = x2 - x1;
		var c1 = x1 * y2 - x2 * y1;
		var l1 = Math.sqrt(a1 * a1 + b1 * b1);

		x2 = _points[6];
		y2 = _points[7];
		var a2 = y1 - y2;
		var b2 = x2 - x1;
		var c2 = x1 * y2 - x2 * y1;
		var l2 = Math.sqrt(a2 * a2 + b2 * b2);

		for (i in 0...numVerts)
		{
			var j = i * 2;
			var x = output[j];
			var y = output[j + 1];

			var da = l2 > 0 ? Math.abs(a2 * x + b2 * y + c2) / l2 : 0;
			var db = l1 > 0 ? Math.abs(a1 * x + b1 * y + c1) / l1 : 0;

			muvout[j    ] = l1 > 0 ? da / l1 : 0;
			muvout[j + 1] = l2 > 0 ? db / l2 : 0;
		}
	}

	private function _inside(x:Float, y:Float, x1:Float, y1:Float, x2:Float, y2:Float):Bool
	{
		return (x2 - x1) * (y - y1) > (y2 - y1) * (x - x1);
	}

	private function _intersection(out:Array<Float>, x1:Float, y1:Float, x2:Float, y2:Float, sx:Float, sy:Float, ex:Float, ey:Float):Void
	{
		var dcx = x1 - x2;
		var dcy = y1 - y2;
		var dpx = sx - ex;
		var dpy = sy - ey;

		var n1 = x1 * y2 - y1 * x2;
		var n2 = sx * ey - sy * ex;
		var n3 = 1.0 / (dcx * dpy - dcy * dpx);

		out[0] = (n1 * dpx - n2 * dcx) * n3;
		out[1] = (n1 * dpy - n2 * dcy) * n3;
	}

	private function _push(x:Float, y:Float, u:Float, v:Float):Void
	{
		var i = _verts * 2;
		var j = i + 1;
		output[i] = x;
		output[j] = y;
		uvout[i] = u;
		uvout[j] = v;
		++_verts;
	}
}
