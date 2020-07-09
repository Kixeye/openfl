package openfl._internal.renderer.kixeye;

import haxe.macro.Expr.Error;
import openfl.display3D.textures.TextureBase;
import js.html.webgl.UniformLocation;
import js.html.webgl.Program;
import js.html.webgl.Shader;
import lime.graphics.WebGLRenderContext;
import openfl._internal.backend.gl.WebGLRenderingContext;

@:access(openfl._internal.renderer.kixeye.KxVertexBuffer)
@:access(openfl._internal.renderer.kixeye.KxTexture)
class KxShader implements KxGLResource
{
	var _gl:WebGLRenderingContext;
	var _program:Program = null;

	public function new(gl:WebGLRenderingContext)
	{
		_gl = gl;
	}

	public function dispose():Void
	{
		if (_program != null)
		{
			_gl.deleteProgram(_program);
			_program = null;
		}
	}

	public function use():Void
	{
		_gl.useProgram(_program);
	}

	public function updateUniform2(loc:UniformLocation, x:Float, y:Float):Void
	{
		_gl.uniform2f(loc, x, y);
	}

	public function getUniform(name:String):UniformLocation
	{
		return _gl.getUniformLocation(_program, name);
	}

	public function bindAttributes(vertexBuffer:KxVertexBuffer):Void
	{
		var index = 0;
		for (attr in vertexBuffer._attributes)
		{
			_gl.bindAttribLocation(_program, index, attr.name);
			++index;
		}
	}

	public function compile(vert:String, frag:String):Bool
	{
		var vertShader = compileShader(vert, _gl.VERTEX_SHADER);
		var fragShader = compileShader(frag, _gl.FRAGMENT_SHADER);

		if (vertShader != null && fragShader != null)
		{
			_program = _gl.createProgram();
			_gl.attachShader(_program, vertShader);
			_gl.attachShader(_program, fragShader);
			_gl.linkProgram(_program);

			var success = _gl.getProgramParameter(_program, _gl.LINK_STATUS);
			if (!success)
			{
				trace("Program failed to link.");
				trace(_gl.getProgramInfoLog(_program));

				_gl.deleteProgram(_program);
				_program = null;

				return false;
			}
			else
			{
				return true;
			}
		}
		return false;
	}

	private function compileShader(source:String, type:Int):Shader
	{
		var shader = _gl.createShader(type);
		_gl.shaderSource(shader, source);
		_gl.compileShader(shader);
		var success = _gl.getShaderParameter(shader, _gl.COMPILE_STATUS);
		if (!success)
		{
			trace("Shader failed to compile");
			trace(_gl.getShaderInfoLog(shader));

			_gl.deleteShader(shader);

			return null;
		}
		return shader;
	}
}
