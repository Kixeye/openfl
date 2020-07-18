package openfl._internal.renderer.kixeye;

#if kixeye
import js.html.webgl.UniformLocation;
#end

import lime.math.Matrix3;
import haxe.io.Int32Array;
import openfl._internal.backend.gl.WebGLRenderingContext;
import openfl._internal.backend.utils.Float32Array;
import openfl._internal.renderer.canvas.CanvasRenderer;
import openfl._internal.renderer.canvas.CanvasTextField;
import openfl._internal.renderer.canvas.CanvasGraphics;
import openfl._internal.renderer.canvas.CanvasShape;
import openfl.display.BlendMode;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.DisplayObject;
import openfl.display.DisplayObjectContainer;
import openfl.display.DisplayObjectRenderer;
import openfl.display.IBitmapDrawable;
import openfl.display.Graphics;
import openfl.display.SimpleButton;
import openfl.display.Stage;
import openfl.display.Tilemap;
import openfl.text.TextField;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import openfl.media.Video;

@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
@:access(openfl.geom.ColorTransform)
@:access(openfl.display.Bitmap)
@:access(openfl.display.BitmapData)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Graphics)
@:access(openfl.display.Stage)
@:access(openfl.display.IBitmapDrawable)
@:access(openfl.display.DisplayObjectRenderer)
@:access(openfl.text.TextField)
@:access(openfl._internal.renderer.canvas.CanvasRenderer)
@:access(openfl._internal.renderer.kixeye.KxTexture)
@:access(openfl._internal.renderer.kixeye.KxBatchRenderer)
class KxRenderer extends DisplayObjectRenderer
{
	public var stage:Stage;
	public var gl:WebGLRenderingContext;
	public var pixelRatio:Float;
	public var softwareRenderer:CanvasRenderer;

	public var maxTextureUnits:Int;
	public var maskUnit:Int;
	public var width:Float;
	public var height:Float;

	public var batchShader:KxShader;
	public var viewUniform:UniformLocation;
	public var defaultTexture:KxTexture;
	public var whiteTexture:KxTexture;
	public var batchAttributes:Array<KxVertexAttribute>;

	private var _batchRenderer:KxBatchRenderer;
	private var _cacheRenderers:Array<KxBatchRenderer>;
	private var _currentRenderer:Int;

	private var _colorTransform:ColorTransform = new ColorTransform();
	private var _rect:Rectangle = new Rectangle();

	public function new(stage:Stage, pixelRatio:Float)
	{
		super();

		this.stage = stage;
		this.pixelRatio = pixelRatio;

		gl = stage.window.context.webgl;

		softwareRenderer = new CanvasRenderer(null);
		softwareRenderer.pixelRatio = pixelRatio;
		softwareRenderer.__worldTransform = __worldTransform;
		softwareRenderer.__worldColorTransform = __worldColorTransform;

		var glslVersion = gl.getParameter(gl.SHADING_LANGUAGE_VERSION);
		trace("Shading language version: " + glslVersion);

		maxTextureUnits = Std.int(Math.min(16, gl.getParameter(gl.MAX_TEXTURE_IMAGE_UNITS)));
		maskUnit = --maxTextureUnits;

		var maxTextureSize:Int = gl.getParameter(gl.MAX_TEXTURE_SIZE);
		trace("Max texture size: " + maxTextureSize);
		if (Graphics.maxTextureWidth == null)
		{
			Graphics.maxTextureWidth = Graphics.maxTextureHeight = maxTextureSize;
		}
		KxTexture.maxTextureSize = maxTextureSize;

		BitmapData.__softwareRenderer = softwareRenderer;

		// initial GL state
		gl.disable(gl.DEPTH_TEST);
		gl.disable(gl.STENCIL_TEST);
		gl.enable(gl.SCISSOR_TEST);
		gl.enable(gl.BLEND);
		gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);

		batchAttributes = [
			new KxVertexAttribute("a_pos", 2, false),
			new KxVertexAttribute("a_uv", 4, false),
			new KxVertexAttribute("a_colorMult", 4, false),
			new KxVertexAttribute("a_colorOffset", 4, false),
			new KxVertexAttribute("a_textureId", 1, false)
		];

		defaultTexture = new KxTexture(gl, null);
		defaultTexture.uploadDefault();

		whiteTexture = new KxTexture(gl, null);
		whiteTexture.uploadWhite();

		batchShader = new KxShader(gl);
		batchShader.compile(QuadShader.VERTEX, QuadShader.FRAGMENT, batchAttributes);
		batchShader.use();
		for (i in 0...maxTextureUnits)
		{
			var uniform = batchShader.getUniform("u_sampler" + i);
			gl.uniform1i(uniform, i);
			defaultTexture.bind(i, false);
		}
		gl.uniform1i(batchShader.getUniform("u_mask"), maskUnit);
		defaultTexture.bind(maskUnit, false);
		viewUniform = batchShader.getUniform("u_view");

		_batchRenderer = new KxBatchRenderer(this);
		_cacheRenderers = [new KxBatchRenderer(this)];
		_currentRenderer = 0;
	}

	private override function __dispose():Void
	{
		softwareRenderer.__dispose();
		softwareRenderer = null;

		for (renderer in _cacheRenderers)
		{
			renderer.dispose();
		}
		_cacheRenderers = null;

		_batchRenderer.dispose();
		_batchRenderer = null;

		defaultTexture.dispose();
		defaultTexture = null;

		whiteTexture.dispose();
		whiteTexture = null;

		batchShader.dispose();
		batchShader = null;
		viewUniform = null;

		batchAttributes = null;
		gl = null;
	}

	private override function __resize(width:Int, height:Int):Void
	{
		this.width = width;
		this.height = height;
	}

	private override function __render(object:IBitmapDrawable):Void
	{
		_batchRenderer.render(cast object, null);
	}

	public function updateCacheBitmap(object:DisplayObject):Void
	{
		if (object.cacheAsBitmap)
		{
			if (object.__cacheBitmapMatrix == null)
			{
				object.__cacheBitmapMatrix = new Matrix();
			}

			var hasFilters = object.__filters != null;
			var bitmapMatrix = (object.__cacheAsBitmapMatrix != null ? object.__cacheAsBitmapMatrix : object.__renderTransform);

			_colorTransform.__copyFrom(object.__worldColorTransform);

			var needRender = (object.__cacheBitmap == null
				|| (object.__renderDirty && (object.__children != null && object.__children.length > 0))
				|| object.opaqueBackground != object.__cacheBitmapBackground);

			if (!needRender
				&& (bitmapMatrix.a != object.__cacheBitmapMatrix.a
					|| bitmapMatrix.b != object.__cacheBitmapMatrix.b
					|| bitmapMatrix.c != object.__cacheBitmapMatrix.c
					|| bitmapMatrix.d != object.__cacheBitmapMatrix.d))
			{
				needRender = true;
			}

			if (hasFilters && !needRender)
			{
				for (filter in object.__filters)
				{
					if (filter.__renderDirty)
					{
						needRender = true;
						break;
					}
				}
			}

			var updateTransform = (needRender || !object.__cacheBitmap.__worldTransform.equals(object.__worldTransform));

			object.__cacheBitmapMatrix.copyFrom(bitmapMatrix);
			object.__cacheBitmapMatrix.tx = 0;
			object.__cacheBitmapMatrix.ty = 0;

			// TODO: Handle dimensions better if object has a scrollRect?

			var bitmapWidth = 0, bitmapHeight = 0;
			var filterWidth = 0, filterHeight = 0;
			var offsetX = 0., offsetY = 0.;

			if (updateTransform)
			{
				_rect.setTo(0, 0, 0, 0);
				object.__getFilterBounds(_rect, object.__cacheBitmapMatrix);

				filterWidth = Math.ceil(_rect.width * pixelRatio);
				filterHeight = Math.ceil(_rect.height * pixelRatio);

				offsetX = _rect.x > 0 ? Math.ceil(_rect.x) : Math.floor(_rect.x);
				offsetY = _rect.y > 0 ? Math.ceil(_rect.y) : Math.floor(_rect.y);

				if (object.__renderTarget != null)
				{
					if (filterWidth > object.__renderTarget.width || filterHeight > object.__renderTarget.height)
					{
						bitmapWidth = filterWidth;
						bitmapHeight = filterHeight;
						needRender = true;
					}
					else
					{
						bitmapWidth = object.__renderTarget.width;
						bitmapHeight = object.__renderTarget.height;
					}
				}
				else
				{
					bitmapWidth = filterWidth;
					bitmapHeight = filterHeight;
				}
			}

			if (needRender)
			{
				updateTransform = true;
				object.__cacheBitmapBackground = object.opaqueBackground;

				if (filterWidth >= 0.5 && filterHeight >= 0.5)
				{
					var needsFill = (object.opaqueBackground != null && (bitmapWidth != filterWidth || bitmapHeight != filterHeight));
					var fillColor = object.opaqueBackground != null ? (0xFF << 24) | object.opaqueBackground : 0;

					if (object.__renderTarget == null
						|| bitmapWidth > object.__renderTarget.width
						|| bitmapHeight > object.__renderTarget.height)
					{
						object.__renderTarget = new KxRenderTarget(gl, bitmapWidth, bitmapHeight);
					}
					object.__renderTarget.setClearColor(0);
					if (needsFill)
					{
						object.__renderTarget.setClearColor(fillColor);
					}
				}
				else
				{
					object.__cacheBitmap = null;
					if (object.__renderTarget != null)
					{
						object.__renderTarget.dispose();
						object.__renderTarget = null;
					}
					return;
				}
			}

			if (object.__cacheBitmap == null)
			{
				object.__cacheBitmap = new Bitmap();
			}

			if (updateTransform)
			{
				object.__cacheBitmap.__worldTransform.copyFrom(object.__worldTransform);

				if (bitmapMatrix == object.__renderTransform)
				{
					object.__cacheBitmap.__renderTransform.identity();
					object.__cacheBitmap.__renderTransform.scale(1 / pixelRatio, 1 / pixelRatio);
					object.__cacheBitmap.__renderTransform.tx = object.__renderTransform.tx + offsetX;
					object.__cacheBitmap.__renderTransform.ty = object.__renderTransform.ty + offsetY;
				}
				else
				{
					object.__cacheBitmap.__renderTransform.copyFrom(object.__cacheBitmapMatrix);
					object.__cacheBitmap.__renderTransform.invert();
					object.__cacheBitmap.__renderTransform.concat(object.__renderTransform);
					object.__cacheBitmap.__renderTransform.tx += offsetX;
					object.__cacheBitmap.__renderTransform.ty += offsetY;
				}
			}

			object.__cacheBitmap.smoothing = __allowSmoothing;
			object.__cacheBitmap.__renderable = object.__renderable;
			object.__cacheBitmap.__worldAlpha = object.__worldAlpha;
			object.__cacheBitmap.__worldBlendMode = object.__worldBlendMode;
			object.__cacheBitmap.__worldShader = object.__worldShader;
			object.__cacheBitmap.mask = object.__mask;

			if (needRender)
			{
				var renderer = _pushRenderer();

				renderer._worldAlpha = 1 / object.__worldAlpha;
				renderer._worldTransform.copyFrom(object.__renderTransform);
				renderer._worldTransform.invert();
				renderer._worldTransform.concat(object.__cacheBitmapMatrix);
				renderer._worldTransform.tx -= offsetX;
				renderer._worldTransform.ty -= offsetY;
				//renderer._worldTransform.scale(pixelRatio, pixelRatio);
				renderer._worldColorTransform.__copyFrom(_colorTransform);
				renderer._worldColorTransform.__invert();
				renderer.render(object, object.__renderTarget);
				if (hasFilters)
				{
					_renderFilters(object, filterWidth, filterHeight);
				}
				_popRenderer();
			}
		}
		else if (object.__cacheBitmap != null)
		{
			object.__cacheBitmap = null;
			if (object.__renderTarget != null)
			{
				object.__renderTarget.dispose();
				object.__renderTarget = null;
			}
		}
	}

	private function _renderFilters(object:DisplayObject, width:Int, height:Int):Void
	{
		for (filter in object.__filters)
		{
			filter.__renderDirty = false;
		}
	}

	private function _pushRenderer():KxBatchRenderer
	{
		if (_currentRenderer >= _cacheRenderers.length)
		{
			_cacheRenderers.push(new KxBatchRenderer(this));
		}
		var renderer = _cacheRenderers[_currentRenderer++];
		return renderer;
	}

	private function _popRenderer():Void
	{
		--_currentRenderer;
	}
}

private class QuadShader
{
	public static inline var VERTEX:String = '
		precision mediump float;

		uniform mat3 u_view;

		attribute vec2 a_pos;
		attribute vec4 a_uv;
		attribute vec4 a_colorMult;
		attribute vec4 a_colorOffset;
		attribute float a_textureId;

		varying vec4 v_uv;
		varying vec4 v_colorMult;
		varying vec4 v_colorOffset;
		varying float v_textureId;

		void main(void)
		{
			v_uv = a_uv;
			v_colorMult = a_colorMult;
			v_colorOffset = a_colorOffset / 255.0;
			v_textureId = a_textureId;

			vec3 p = vec3(a_pos, 1) * u_view;
			gl_Position = vec4(p, 1);
		}
	';

	public static inline var FRAGMENT:String = '
		precision mediump float;

		varying vec4 v_uv;
		varying vec4 v_colorMult;
		varying vec4 v_colorOffset;
		varying float v_textureId;

		uniform sampler2D u_sampler0;
		uniform sampler2D u_sampler1;
		uniform sampler2D u_sampler2;
		uniform sampler2D u_sampler3;
		uniform sampler2D u_sampler4;
		uniform sampler2D u_sampler5;
		uniform sampler2D u_sampler6;
		uniform sampler2D u_sampler7;
		uniform sampler2D u_sampler8;
		uniform sampler2D u_sampler9;
		uniform sampler2D u_sampler10;
		uniform sampler2D u_sampler11;
		uniform sampler2D u_sampler12;
		uniform sampler2D u_sampler13;
		uniform sampler2D u_sampler14;
		uniform sampler2D u_mask;

		void main(void)
		{
			vec4 color;

			if (v_textureId == 0.0) color = texture2D(u_sampler0, v_uv.xy);
			else if (v_textureId == 1.0) color = texture2D(u_sampler1, v_uv.xy);
			else if (v_textureId == 2.0) color = texture2D(u_sampler2, v_uv.xy);
			else if (v_textureId == 3.0) color = texture2D(u_sampler3, v_uv.xy);
			else if (v_textureId == 4.0) color = texture2D(u_sampler4, v_uv.xy);
			else if (v_textureId == 5.0) color = texture2D(u_sampler5, v_uv.xy);
			else if (v_textureId == 6.0) color = texture2D(u_sampler6, v_uv.xy);
			else if (v_textureId == 7.0) color = texture2D(u_sampler7, v_uv.xy);
			else if (v_textureId == 8.0) color = texture2D(u_sampler8, v_uv.xy);
			else if (v_textureId == 9.0) color = texture2D(u_sampler9, v_uv.xy);
			else if (v_textureId == 10.0) color = texture2D(u_sampler10, v_uv.xy);
			else if (v_textureId == 11.0) color = texture2D(u_sampler11, v_uv.xy);
			else if (v_textureId == 12.0) color = texture2D(u_sampler12, v_uv.xy);
			else if (v_textureId == 13.0) color = texture2D(u_sampler13, v_uv.xy);
			else if (v_textureId == 14.0) color = texture2D(u_sampler14, v_uv.xy);

			vec4 mask = texture2D(u_mask, v_uv.zw);

			color.rgb /= color.a;
			color = clamp((color * v_colorMult) + v_colorOffset, 0.0, 1.0);
			gl_FragColor = vec4(color.rgb * color.a, color.a) * mask.a;
		}
	';
}
