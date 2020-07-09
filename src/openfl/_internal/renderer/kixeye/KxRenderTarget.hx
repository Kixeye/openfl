package openfl._internal.renderer.kixeye;

import js.html.webgl.Framebuffer;
import openfl._internal.backend.gl.WebGLRenderingContext;

class KxRenderTarget implements KxGLResource
{
	private var _gl:WebGLRenderingContext;
	private var _fb:Framebuffer = null;

	public function new(gl:WebGLRenderingContext)
	{
		_gl = gl;
		_fb = _gl.createFramebuffer();
	}

	public function dispose():Void
	{
		if (_fb != null)
		{
			_gl.deleteFramebuffer(_fb);
		}
	}

	public function resize(width:Int, height:Int):Void
	{

	}


}
