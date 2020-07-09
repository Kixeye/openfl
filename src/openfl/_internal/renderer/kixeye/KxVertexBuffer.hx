package openfl._internal.renderer.kixeye;

import js.html.webgl.Buffer;
import haxe.io.Int32Array;
import openfl._internal.backend.gl.WebGLRenderingContext;
import openfl._internal.backend.utils.Float32Array;
import openfl._internal.backend.utils.UInt16Array;

class KxVertexBuffer implements KxGLResource
{
	private static inline var NUM_BUFFERS:Int = 2; // double buffering

	private var _gl:WebGLRenderingContext;
	private var _bufferIndex:Int = 0;
	private var _vertexBuffers:Array<Buffer> = [];
	private var _indexBuffers:Array<Buffer> = [];
	private var _vertices:Float32Array = null;
	private var _indices:UInt16Array = null;

	private var _attributes:Array<Attribute> = [];
	private var _stride:Int = 0;

	private var _numFloats:Int = 0;
	private var _numIndices:Int = 0;

	public function new(gl:WebGLRenderingContext)
	{
		_gl = gl;
	}

	public function getNumIndices():Int
	{
		return _numIndices;
	}

	public function getNumVertices():Int
	{
		return Std.int(_numFloats / _stride);
	}

	public function dispose():Void
	{
		for (buffer in _vertexBuffers)
		{
			_gl.deleteBuffer(buffer);
		}
		for (buffer in _indexBuffers)
		{
			_gl.deleteBuffer(buffer);
		}
		_vertexBuffers = [];
		_indexBuffers = [];
		_vertices = null;
		_indices = null;
	}

	public function attribute(name:String, size:Int, norm:Bool):Void
	{
		_attributes.push(new Attribute(name, size, norm));
		_stride += size;
	}

	public function commit(maxVertices:Int, maxIndices:Int):Int
	{
		_vertices = new Float32Array(maxVertices * _stride);
		for (i in 0...NUM_BUFFERS)
		{
			var vertexBuffer = _gl.createBuffer();
			_gl.bindBuffer(_gl.ARRAY_BUFFER, vertexBuffer);
			_gl.bufferData(_gl.ARRAY_BUFFER, _vertices, _gl.DYNAMIC_DRAW);
			_vertexBuffers.push(vertexBuffer);

		}
		if (maxIndices > 0)
		{
			_indices = new UInt16Array(maxIndices);
			for (i in 0...NUM_BUFFERS)
			{
				var indexBuffer = _gl.createBuffer();
				_gl.bindBuffer(_gl.ELEMENT_ARRAY_BUFFER, indexBuffer);
				_gl.bufferData(_gl.ELEMENT_ARRAY_BUFFER, _indices, _gl.DYNAMIC_DRAW);
				_indexBuffers.push(indexBuffer);
			}
		}
		return _stride;
	}

	public function begin():Void
	{
		_bufferIndex = (_bufferIndex + 1) % NUM_BUFFERS;
		_numFloats = 0;
		_numIndices = 0;
	}

	public function push(vertices:Array<Float>, indices:Array<Int>):Void
	{
		var offset = getNumVertices();

		for (v in vertices)
		{
			_vertices[_numFloats++] = v;
		}

		if (indices != null)
		{
			for (i in indices)
			{
				_indices[_numIndices++] = offset + i;
			}
		}
	}

	public function end():Void
	{
		_gl.bindBuffer(_gl.ARRAY_BUFFER, _vertexBuffers[_bufferIndex]);
		_gl.bufferSubData(_gl.ARRAY_BUFFER, 0, _vertices.subarray(0, _numFloats));

		if (_indices != null)
		{
			_gl.bindBuffer(_gl.ELEMENT_ARRAY_BUFFER, _indexBuffers[_bufferIndex]);
			_gl.bufferSubData(_gl.ELEMENT_ARRAY_BUFFER, 0, _indices.subarray(0, _numIndices));
		}
	}

	public function enable():Void
	{
		_gl.bindBuffer(_gl.ARRAY_BUFFER, _vertexBuffers[_bufferIndex]);
		if (_indices != null)
		{
			_gl.bindBuffer(_gl.ELEMENT_ARRAY_BUFFER, _indexBuffers[_bufferIndex]);
		}

		var strideBytes = _stride * 4;
		var index = 0;
		var offsetBytes = 0;
		for (attr in _attributes)
		{
			_gl.enableVertexAttribArray(index);
			_gl.vertexAttribPointer(index, attr.size, _gl.FLOAT, attr.norm, strideBytes, offsetBytes);
			offsetBytes += attr.size * 4;
			++index;
		}
	}

	public function draw(offset:Int, count:Int):Void
	{
		if (_indices != null)
		{
			_gl.drawElements(_gl.TRIANGLES, count, _gl.UNSIGNED_SHORT, offset * 2);
		}
		else
		{
			_gl.drawArrays(_gl.TRIANGLES, offset, count);
		}
	}
}

private class Attribute
{
	public var name:String;
	public var size:Int;
	public var norm:Bool;

	public function new(name:String, size:Int, norm:Bool)
	{
		this.name = name;
		this.size = size;
		this.norm = norm;
	}
}
