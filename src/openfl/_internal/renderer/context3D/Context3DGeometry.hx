package openfl._internal.renderer.context3D;

import openfl._internal.utils.Float32Array;
import openfl.display.Geometry;
import openfl.geom.Matrix;
#if gl_stats
import openfl._internal.renderer.context3D.stats.Context3DStats;
import openfl._internal.renderer.context3D.stats.DrawCallContext;
#end

#if !openfl_debug
@:fileXml(' tags="haxe,release" ')
@:noDebug
#end
@:access(openfl.display.Geometry)
@:access(openfl.display.DisplayObject)
@:access(openfl.display.Shader)
@:access(openfl.display3D.Context3D)
@:access(openfl.display3D.VertexBuffer3D)
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Matrix)
@:access(openfl._internal.renderer.context3D.batcher.BatchRenderer)
@SuppressWarnings("checkstyle:FieldDocComment")
class Context3DGeometry
{
	public static function render(geometry:Geometry, renderer:Context3DRenderer):Void
	{
		if (!geometry.__visible || geometry.__worldAlpha <= 0) return;

		var context = renderer.context3D;

		if (geometry.__vertexBuffer == null && geometry.__vertices.length > 0)
		{
			geometry.__vertexBuffer = context.createVertexBuffer(geometry.__numVertices, Geometry.FLOATS_PER_VERTEX, STATIC_DRAW);

			var vertices = new Float32Array(geometry.__vertices);
			geometry.__vertexBuffer.uploadFromTypedArray(vertices);
		}

		if (geometry.__vertexBuffer != null)
		{
			renderer.batcher.flush();

			var vertexBuffer = geometry.__vertexBuffer;
			var shader = Geometry.__geomShader;
			context.setScissorRectangle(null);
			renderer.__setBlendMode(geometry.blendMode);

			renderer.setShader(shader);

			// TODO: use color transform values
			// shader.uColorMultiplier.value[0] = 1;
			// shader.uColorMultiplier.value[1] = 1;
			// shader.uColorMultiplier.value[2] = 1;
			// shader.uColorMultiplier.value[3] = 1;

			// shader.uColorOffset.value[0] = 0;
			// shader.uColorOffset.value[1] = 0;
			// shader.uColorOffset.value[2] = 0;
			// shader.uColorOffset.value[3] = 0;

			renderer.applyMatrix(renderer.__getMatrix(geometry.__renderTransform, AUTO));
			renderer.updateShader();

			context.setVertexBufferAt(shader.__position.index, vertexBuffer, 0, FLOAT_2);
			context.setVertexBufferAt(shader.aColor.index, vertexBuffer, 2, FLOAT_4);

			context.__drawTriangles(0, geometry.__numVertices);

			#if gl_stats
			Context3DStats.incrementDrawCall(DrawCallContext.BATCHER);
			#end
		}
	}
}
