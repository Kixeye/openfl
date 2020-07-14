package openfl._internal.renderer.kixeye;

import js.html.webgl.Framebuffer;
import js.html.webgl.Texture;

import openfl._internal.backend.gl.WebGLRenderingContext;

class KxRenderTarget implements KxGLResource
{
	private var gl:WebGLRenderingContext;

	private var _fb:Framebuffer = null;
	private var _texture:Texture = null;
	private var _width:Int = 0;
	private var _height:Int = 0;

	public function new(gl:WebGLRenderingContext)
	{
		this.gl = gl;
		_fb = gl.createFramebuffer();
	}

	public function dispose():Void
	{
		if (_fb != null)
		{
			gl.deleteFramebuffer(_fb);
			_fb = null;
		}
	}

	public function getTexture():KxTexture
	{
		return null;
	}

	public function resize(width:Int, height:Int):Void
	{
		if (_width != width || _height != height)
		{
		}
	}

	public function viewport(x:Int, y:Int, w:Int, h:Int):Void
	{
	}
}
