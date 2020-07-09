package openfl._internal.renderer.kixeye;

import lime.utils.Bytes;
import lime.utils.UInt8Array;
import js.html.webgl.Texture;
import js.html.VideoElement;
import lime.graphics.Image;
import openfl._internal.renderer.SamplerState;
import openfl._internal.backend.gl.WebGLRenderingContext;

class KxTexture implements KxGLResource
{
	private var _gl:WebGLRenderingContext;
	private var _texture:Texture = null;
	private var _width:Int = 0;
	private var _height:Int = 0;

	public var valid:Bool = false;

	#if debug
	private var _src:Dynamic = null;
	#end

	public function new(gl:WebGLRenderingContext, image:Image)
	{
		_gl = gl;

		_texture = _gl.createTexture();
		_gl.bindTexture(_gl.TEXTURE_2D, _texture);
		if (image != null)
		{
			upload(image);
		}
	}

	public function bind(textureUnit:Int, smooth:Bool):Void
	{
		_gl.activeTexture(_gl.TEXTURE0 + textureUnit);
		_gl.bindTexture(_gl.TEXTURE_2D, _texture);
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_MIN_FILTER, smooth ? _gl.LINEAR : _gl.NEAREST);
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_MAG_FILTER, smooth ? _gl.LINEAR : _gl.NEAREST);
	}

	public function upload(image:Image):Void
	{
		if (image == null)
		{
			return;
		}

		_width = image.width;
		_height = image.height;

		#if debug
		_src = image.src;
		#end

		if (_width == 0 || _height == 0)
		{
			trace("Invalid texture size: " + _width + "x" + _height);
			return;
		}
		_gl.bindTexture(_gl.TEXTURE_2D, _texture);

		var internalFormat, format;
		if (image.buffer.bitsPerPixel == 1)
		{
			internalFormat = _gl.ALPHA;
			format = _gl.ALPHA;
		}
		else
		{
			internalFormat = _gl.RGBA;
			format = _gl.RGBA;
		}

		if ((image.type != DATA && !image.premultiplied) || (!image.premultiplied && image.transparent))
		{
			_gl.pixelStorei(_gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
		}
		if (image.type == DATA)
		{
			_gl.texImage2D(_gl.TEXTURE_2D, 0, internalFormat, image.buffer.width, image.buffer.height, 0, format, _gl.UNSIGNED_BYTE, image.data);
		}
		else
		{
			_gl.texImage2D(_gl.TEXTURE_2D, 0, internalFormat, format, _gl.UNSIGNED_BYTE, image.src);
		}
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_WRAP_S, _gl.CLAMP_TO_EDGE);
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_WRAP_T, _gl.CLAMP_TO_EDGE);

		valid = true;
	}

	public function uploadDefault():Void
	{
		var w = 64;
		var h = 64;
		var image = new Image(null, 0, 0, w, h, 0, DATA);
		for (i in 0...w)
		{
			for (j in 0...h)
			{
				var c = ((i & 8) ^ (j & 8)) * 0xFFFFFFFF;
				image.setPixel32(i, j, c | 0x000000FF);
			}
		}
		upload(image);
	}

	public function uploadVideo(video:VideoElement):Void
	{
		_gl.bindTexture(_gl.TEXTURE_2D, _texture);
		_gl.texImage2D(_gl.TEXTURE_2D, 0, _gl.RGBA, _gl.RGBA, _gl.UNSIGNED_BYTE, video);
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_WRAP_S, _gl.CLAMP_TO_EDGE);
		_gl.texParameteri(_gl.TEXTURE_2D, _gl.TEXTURE_WRAP_T, _gl.CLAMP_TO_EDGE);
		_width = video.width;
		_height = video.height;
		valid = true;
	}

	public function dispose():Void
	{
		if (_texture != null)
		{
			_gl.deleteTexture(_texture);
			_texture = null;
			valid = false;
		}
	}
}
