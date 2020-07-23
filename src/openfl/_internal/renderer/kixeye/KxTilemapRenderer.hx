package openfl._internal.renderer.kixeye;

import openfl.display.BitmapData;
import openfl.display.BlendMode;
import openfl.display.Shader;
import openfl.display.TileContainer;
import openfl.display.Tilemap;
import openfl.display.Tileset;
import openfl.display3D.Context3D;
import openfl.geom.ColorTransform;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;

@:access(openfl.display.BitmapData)
@:access(openfl.display.Shader)
@:access(openfl.display.Tilemap)
@:access(openfl.display.Tileset)
@:access(openfl.display.Tile)
@:access(openfl.filters.BitmapFilter)
@:access(openfl.geom.ColorTransform)
@:access(openfl.geom.Matrix)
@:access(openfl.geom.Rectangle)
@:access(openfl._internal.renderer.kixeye.KxRenderer)
class KxTilemapRenderer
{
	private var cacheColorTransform = new ColorTransform();
	private var _renderer:KxRenderer;

	public function new (renderer:KxRenderer)
	{
		_renderer = renderer;
	}

	public function render(tilemap:Tilemap)
	{
		if (tilemap.__group.__tiles.length == 0) return;

		var rect = Rectangle.__pool.get();
		var matrix = Matrix.__pool.get();
		var parentTransform = tilemap.__renderTransform;

		buildBufferTileContainer(tilemap, tilemap.__group, parentTransform, tilemap.__tileset, tilemap.tileAlphaEnabled, tilemap.__worldAlpha,
			tilemap.tileColorTransformEnabled, tilemap.__worldColorTransform, null, rect, matrix);

		Rectangle.__pool.release(rect);
		Matrix.__pool.release(matrix);
	}

	private function buildBufferTileContainer(tilemap:Tilemap, group:TileContainer, parentTransform:Matrix,
			defaultTileset:Tileset, alphaEnabled:Bool, worldAlpha:Float, colorTransformEnabled:Bool, defaultColorTransform:ColorTransform,
			cacheBitmapData:BitmapData, rect:Rectangle, matrix:Matrix):Void
	{
		var tileTransform = Matrix.__pool.get();

		var tiles = group.__tiles;
		var length = group.__length;

		var tile,
			tileset,
			alpha,
			visible,
			colorTransform = null,
			id,
			tileData,
			tileRect,
			bitmapData;
		var tileWidth, tileHeight, uvX, uvY, uvHeight, uvWidth, vertexOffset;

		for (tile in tiles)
		{
			tileTransform.setTo(1, 0, 0, 1, -tile.originX, -tile.originY);
			tileTransform.concat(tile.matrix);
			tileTransform.concat(parentTransform);

			tileset = tile.tileset != null ? tile.tileset : defaultTileset;

			alpha = tile.alpha * worldAlpha;
			visible = tile.visible;
			tile.__dirty = false;

			if (!visible || alpha <= 0) continue;

			if (colorTransformEnabled)
			{
				if (tile.colorTransform != null)
				{
					if (defaultColorTransform == null)
					{
						colorTransform = tile.colorTransform;
					}
					else
					{
						colorTransform = cacheColorTransform;
						colorTransform.redMultiplier = defaultColorTransform.redMultiplier * tile.colorTransform.redMultiplier;
						colorTransform.greenMultiplier = defaultColorTransform.greenMultiplier * tile.colorTransform.greenMultiplier;
						colorTransform.blueMultiplier = defaultColorTransform.blueMultiplier * tile.colorTransform.blueMultiplier;
						colorTransform.alphaMultiplier = defaultColorTransform.alphaMultiplier * tile.colorTransform.alphaMultiplier;
						colorTransform.redOffset = defaultColorTransform.redOffset + tile.colorTransform.redOffset;
						colorTransform.greenOffset = defaultColorTransform.greenOffset + tile.colorTransform.greenOffset;
						colorTransform.blueOffset = defaultColorTransform.blueOffset + tile.colorTransform.blueOffset;
						colorTransform.alphaOffset = defaultColorTransform.alphaOffset + tile.colorTransform.alphaOffset;
					}
				}
				else
				{
					colorTransform = defaultColorTransform;
				}
			}

			if (!alphaEnabled) alpha = 1;

			if (tile.__length > 0)
			{
				buildBufferTileContainer(tilemap, cast tile, tileTransform, tileset, alphaEnabled, alpha, colorTransformEnabled, colorTransform,
					cacheBitmapData, rect, matrix);
			}
			else
			{
				if (tileset == null) continue;

				id = tile.id;

				bitmapData = tileset.__bitmapData;
				if (bitmapData == null) continue;

				if (id == -1)
				{
					tileRect = tile.__rect;
					if (tileRect == null || tileRect.width <= 0 || tileRect.height <= 0) continue;

					uvX = tileRect.x / bitmapData.width;
					uvY = tileRect.y / bitmapData.height;
					uvWidth = tileRect.right / bitmapData.width;
					uvHeight = tileRect.bottom / bitmapData.height;
				}
				else
				{
					tileData = tileset.__data[id];
					if (tileData == null) continue;

					rect.setTo(tileData.x, tileData.y, tileData.width, tileData.height);
					tileRect = rect;

					uvX = tileData.__uvX;
					uvY = tileData.__uvY;
					uvWidth = tileData.__uvWidth;
					uvHeight = tileData.__uvHeight;
				}

				tileWidth = tileRect.width;
				tileHeight = tileRect.height;

				_renderer._setVertices(tileTransform, 0, 0, tileWidth, tileHeight);
				_renderer._setUvs(uvX, uvY, uvWidth, uvHeight);

				var blendMode = tilemap.__worldBlendMode;
				if (tilemap.tileBlendModeEnabled)
				{
					blendMode = (tile.__blendMode != null) ? tile.__blendMode : blendMode;
				}

				_renderer._push(bitmapData.getTexture(_renderer), blendMode, alpha, colorTransform);
			}
		}
		group.__dirty = false;
		Matrix.__pool.release(tileTransform);
	}
}
