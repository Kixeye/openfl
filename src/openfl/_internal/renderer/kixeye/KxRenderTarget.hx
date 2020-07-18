package openfl._internal.renderer.kixeye;

import js.html.webgl.Framebuffer;
import js.html.webgl.Texture;
import openfl.geom.Matrix;

import openfl._internal.backend.gl.WebGLRenderingContext;

@:access(openfl._internal.renderer.kixeye.KxTexture)
class KxRenderTarget implements KxGLResource
{
	public var width:Int;
	public var height:Int;
	public var texture:KxTexture;

	private var gl:WebGLRenderingContext;

	private var _fb:Framebuffer = null;
	private var _clearColor:Array<Float> = [0, 0, 0, 0];

	public function new(gl:WebGLRenderingContext, width:Int, height:Int)
	{
		this.gl = gl;
		this.width = width;
		this.height = height;

		texture = new KxTexture(gl, null);
		texture.initRenderTarget(width, height);

		_fb = gl.createFramebuffer();
		gl.bindFramebuffer(gl.FRAMEBUFFER, _fb);
		gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, texture._texture, 0);
	}

	public function dispose():Void
	{
		if (_fb != null)
		{
			gl.deleteFramebuffer(_fb);
			_fb = null;
		}
		if (texture != null)
		{
			texture.dispose();
			texture = null;
		}
		gl = null;
	}

	public function bind():Void
	{
		var w = Std.int(width);
		var h = Std.int(height);
		gl.bindFramebuffer(gl.FRAMEBUFFER, _fb);
		gl.viewport(0, 0, w, h);
		gl.scissor(0, 0, w, h);
		gl.clearColor(_clearColor[0], _clearColor[1], _clearColor[2], _clearColor[3]);
		gl.clear(gl.COLOR_BUFFER_BIT);
	}

	public function setClearColor(color:UInt):Void
	{
		var a = (color & 0xFF000000) >>> 24;
		var r = (color & 0xFF0000) >>> 16;
		var g = (color & 0x00FF00) >>> 8;
		var b = (color & 0x0000FF);

		_clearColor[0] = r / 0xFF;
		_clearColor[1] = g / 0xFF;
		_clearColor[2] = b / 0xFF;
		_clearColor[3] = a / 0xFF;
	}
}
