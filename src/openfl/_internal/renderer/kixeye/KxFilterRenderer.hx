package openfl._internal.renderer.kixeye;

import openfl.display.DisplayObject;
import openfl._internal.backend.gl.WebGLRenderingContext;

@:access(openfl.display.DisplayObject)
@:access(openfl.filters.BitmapFilter)
class KxFilterRenderer
{
	private var gl:WebGLRenderingContext;

	public function new(gl:WebGLRenderingContext)
	{
		this.gl = gl;
	}

	public function render(obj:DisplayObject):Void
	{
		var dirty = false;
		for (filter in obj.__filters)
		{
			if (filter.__renderDirty)
			{
				dirty = true;
				break;
			}
		}
		if (!dirty)
		{
			return;
		}
	}

}
