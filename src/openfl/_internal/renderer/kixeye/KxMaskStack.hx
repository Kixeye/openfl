package openfl._internal.renderer.kixeye;

import openfl.display.DisplayObject;
import openfl._internal.renderer.canvas.CanvasRenderer;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.backend.gl.WebGLRenderingContext;

@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
class KxMaskStack
{
	private var gl:WebGLRenderingContext;
	private var _softwareRenderer:CanvasRenderer;
	private var _textureUnit:Int;
	private var _whiteTexture:KxTexture;
	private var _stack:Array<DisplayObject> = [];
	private var _size:Int = 0;

	public function new(gl:WebGLRenderingContext, softwareRenderer:CanvasRenderer, textureUnit:Int)
	{
		this.gl = gl;
		_softwareRenderer = softwareRenderer;
		_textureUnit = textureUnit;
		_whiteTexture = new KxTexture(gl, null);
		_whiteTexture.uploadWhite();
	}

	public function top():Int
	{
		return _size - 1;
	}

	public function bind(id:Int):Void
	{
		if (id == -1)
		{
			_whiteTexture.bind(_textureUnit, false);
		}
		else
		{
			// TODO
			// var obj = _stack[id];
			// if (obj.__graphics != null && obj.__graphics.__bitmap != null)
			// {
			// 	var texture = obj.__graphics.__bitmap.getTexture(gl);
			// 	texture.bind(_textureUnit, true);
			// }
			// else
			{
				_whiteTexture.bind(_textureUnit, false);
			}
		}
	}

	public function begin():Void
	{
		_size = 0;
	}

	public function push(obj:DisplayObject):Void
	{
		if (_stack.length <= _size)
		{
			_stack.push(obj);
		}
		else
		{
			_stack[_size] = obj;
		}
		if (obj.__graphics != null)
		{
			CanvasGraphics.render(obj.__graphics, _softwareRenderer);
		}
		++_size;
	}

	public function pop():Void
	{
		--_size;
	}

}
