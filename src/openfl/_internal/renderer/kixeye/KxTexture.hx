package openfl._internal.renderer.kixeye;

import js.html.webgl.Texture;
import js.html.VideoElement;
import lime.utils.Bytes;
import lime.utils.UInt8Array;
import lime.graphics.Image;
import openfl._internal.renderer.SamplerState;
import openfl._internal.backend.gl.WebGLRenderingContext;

class KxTexture implements KxGLResource
{
	public var renderer:KxRenderer;
	public var gl:WebGLRenderingContext;
	public var version:Int = -1;
	private var _texture:Texture = null;
	private var _width:Int = 0;
	private var _height:Int = 0;

	public var pixelScale:Float = 1.0;

	public var valid:Bool = false;

	public static var maxTextureSize:Int = 0;

	#if debug
	private var _src:Dynamic = null;
	#end

	public function new(renderer:KxRenderer, image:Image)
	{
		this.renderer = renderer;
		this.gl = renderer.gl;

		_texture = gl.createTexture();
		gl.bindTexture(gl.TEXTURE_2D, _texture);
		if (image != null)
		{
			upload(image);
		}
	}

	public function bind(textureUnit:Int, smooth:Bool):Void
	{
		gl.activeTexture(gl.TEXTURE0 + textureUnit);
		gl.bindTexture(gl.TEXTURE_2D, _texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, smooth ? gl.LINEAR : gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, smooth ? gl.LINEAR : gl.NEAREST);
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

		var scaled = false;

		if (_width > maxTextureSize || _height > maxTextureSize)
		{
			trace("Texture too large: " + _width + "x" + _height);

			var largeSide = Math.max(_width, _height);
			var scale = maxTextureSize / largeSide;

			_width = Math.floor(_width * scale);
			_height = Math.floor(_height * scale);

			trace("Scaled down size: " + _width + "x" + _height);

			image.resize(_width, _height);

			pixelScale = scale;
			scaled = true;
		}

		gl.bindTexture(gl.TEXTURE_2D, _texture);

		var internalFormat, format;
		if (image.buffer.bitsPerPixel == 1)
		{
			internalFormat = gl.ALPHA;
			format = gl.ALPHA;
		}
		else
		{
			internalFormat = gl.RGBA;
			format = gl.RGBA;
		}

		if ((image.type != DATA && !image.premultiplied) || (!image.premultiplied && image.transparent))
		{
			gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, 1);
		}
		if (image.type == DATA || scaled)
		{
			gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, image.buffer.width, image.buffer.height, 0, format, gl.UNSIGNED_BYTE, image.data);
		}
		else
		{
			gl.texImage2D(gl.TEXTURE_2D, 0, internalFormat, format, gl.UNSIGNED_BYTE, image.src);
		}
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

		version = image.version;
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

	public function uploadWhite():Void
	{
		var w = 4;
		var h = 4;
		var image = new Image(null, 0, 0, w, h, 0, DATA);
		for (i in 0...w)
		{
			for (j in 0...h)
			{
				image.setPixel32(i, j, 0xFFFFFFFF);
			}
		}
		upload(image);
	}

	public function uploadVideo(video:VideoElement, width:Int, height:Int):Void
	{
		_width = width;
		_height = height;

		gl.bindTexture(gl.TEXTURE_2D, _texture);
		gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, video);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

		valid = true;
	}

	public function dispose():Void
	{
		if (_texture != null)
		{
			gl.deleteTexture(_texture);
			_texture = null;
			valid = false;
			version = -1;
		}
	}
}
