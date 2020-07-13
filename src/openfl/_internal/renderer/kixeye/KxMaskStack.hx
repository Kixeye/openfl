package openfl._internal.renderer.kixeye;

import openfl.display.DisplayObject;
import openfl._internal.backend.gl.WebGLRenderingContext;

class KxMaskStack
{
	private var gl:WebGLRenderingContext;
	private var _whiteTexture:KxTexture;

	public function new(gl:WebGLRenderingContext)
	{
		this.gl = gl;
		_whiteTexture = new KxTexture(gl, null);
		_whiteTexture.uploadWhite();
	}

	public function top():Int
	{
		return -1;
	}

	public function bind(id:Int, unit:Int):Void
	{
		if (id == -1)
		{
			_whiteTexture.bind(unit, false);
		}
		else
		{
			// TODO: bind mask texture
		}
	}

	public function push(obj:DisplayObject):Void
	{
		// TODO: render obj into a RenderTarget and push to stack
	}

	public function pop():Void
	{
	}

}
