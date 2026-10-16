# Kixeye changes on top of openfl 9.5.2

Branch `upgrade/openfl-9.5.2` starts at upstream openfl `9.5.2` (tag `upgrade-base-openfl-9.5.2`).
This table lists every Kixeye commit from the old fork (`kixeye-release`, base `0d075c525`) and what happened to it here.

KxRenderer (Kixeye's WebGL renderer) was carried as its final, production version in `e8005e07b` (`src/openfl/display/_internal/kixeye/`), plus hooks in `8ae63eb5a` (Geometry), `6e75bbac8` (BitmapData/Video textures) and `9ed28fb01` (Stage). Replaying its 35 commits one by one wasn't possible: several were work in progress, and some added code that later commits removed.

| Old fork commit | Change | Here | How |
|---|---|---|---|
| `2fcd297e2` | Fix additional drawn line in some shape commands | — | Already upstream: `cd215b205` (openfl 9.0.0) |
| `ef7326d1b` | Making process tool generate animate libraries by default | — | Not needed: swf 3.4.0 always exports Animate libraries |
| `34bde9fd0` | HDPI support initial commit | — | Already upstream: HDPI built in (openfl 9.2.0+) |
| `cb598d334` | Cleanup. Fixing an issue where TextFields wouldn't render when cacheAsBitmap=true | — | Already upstream: `f657ca664` (9.2.0), `dd6ebf080` (9.5.1) |
| `1b8c3f6f3` | Fixing cacheAsBitmap related high dpi issues. | — | Already upstream (9.2.0, 9.2.1); had no effect under `-Dkixeye` |
| `092b60cc4` | Fixing build | — | Dropped: build fix for `1b8c3f6f3` |
| `ddbe3177f` | Changing batcher filtering to NEAREST (was LINEAR) | — | Dropped: `BatchRenderer` no longer exists |
| `2ca285de6` | Hack: fixing an issue where TextField.stage can be null if MovieClip.gotoAndStop has be... | — | Already upstream: 9.5.2 reads the pixel ratio from the renderer |
| `fa4eab50d` | Fixing compile error | — | Dropped: typo fix for `2ca285de6` |
| `36afb69b1` | Fixing an issue where openfl process could generate folder names that didn't match haxe... | — | Already in swf 3.4.0 (formats the class name before building the folder path) |
| `52c522e9d` | Fixing an issue where fractional hdpi scaling was break TextField rendering | — | Dropped: replaced by later commits |
| `504e297fe` | Fixing tools | — | Dropped: replaced by later commits |
| `321c33c33` | Fixing an issue with fractional pixelRatio and TextField rendering | — | Dropped: replaced by `ce4d46081` |
| `f3dce6122` | Add sound support to AnimateLibrary | — | Dropped: the game's Animate libraries contain no sounds |
| `8bd8b79e8` | Small fix for Haxe 3.4.7 compat | — | Dropped: Haxe 3 only |
| `9dea5d8c8` | Adding mouseEnabled to Tilemap | — | Dropped: game never sets `Tilemap.mouseEnabled` |
| `f8e096c3d` | Fix compilation witth Haxe 4.1.1 | — | Already upstream: `a7f36884d` (openfl 9.0.0) |
| `771c7f2df` | Fixing DisplayObjectContainer.__setStageReference so it doesn't recursively iterate ove... | — | Already upstream (openfl 9.1.0) |
| `bf42b7447` | Initial commit | `e8005e07b`, `6e75bbac8`, `9ed28fb01` | Ported (KxRenderer files + Stage/BitmapData/Video hooks) |
| `85f77db6c` | Tilemap renderer, TextField and Graphics support initial commit | `e8005e07b` | Ported (KxRenderer) |
| `d85696725` | Fixing an issue where render would recurse into invisible objects | `e8005e07b` | Ported (KxRenderer) |
| `a4f0aef75` | Culling quads at renderer level | `e8005e07b` | Ported (KxRenderer) |
| `6dca53716` | Clip rect improvements | `e8005e07b` | Ported (KxRenderer) |
| `da9983743` | Fixing scrollRect | `e8005e07b` | Ported (KxRenderer) |
| `d038f4fb6` | Removing DOMRenderer | — | Dropped: DOM renderer code is inactive in a WebGL build |
| `e132b1078` | Mask stack and filter renderer WIP | `e8005e07b` | Ported (KxRenderer) |
| `321b98a5c` | Fixing hdpi scaling. Improvements | `e8005e07b`, `9ed28fb01` | Ported (KxRenderer HDPI; cacheAsBitmap off under `-Dkixeye`) |
| `c7d4712f0` | Fixing gl.bindAttribLocation order | `e8005e07b` | Ported (KxRenderer) |
| `ce4d46081` | Bug fixes: Graphics update, scrollRect | `e8005e07b` | KxRenderer half ported. `Graphics.__update` half not ported: uses 9.5.2's version (decision D7) |
| `ccff48466` | Tidying, cleanup | `e8005e07b` | Ported (KxRenderer) |
| `3e4dbdf48` | Fixing clip rect stack | `e8005e07b` | Ported (KxRenderer) |
| `67b27dbcf` | Masking WIP | `e8005e07b` | Ported (KxRenderer) |
| `2b1859142` | Masking improvements | `e8005e07b` | Ported (KxRenderer) |
| `3525d26d6` | Fixing masking with hdpi | `e8005e07b` | Ported (KxRenderer) |
| `417546138` | Sanity check for textures too large | `e8005e07b` | Ported (KxRenderer) |
| `7b1c8104b` | Scaling down large textures on the fly | `e8005e07b` | Ported (KxRenderer) |
| `3f9aef14c` | Fixing Video | `e8005e07b`, `6e75bbac8` | Ported (Video texture) |
| `9471f4ad9` | Fixing GL context loss recovery | `e8005e07b`, `6e75bbac8`, `9ed28fb01` | Ported (context-loss recovery: renderer `__dispose`, textures tied to the renderer) |
| `fe135673d` | Sutherland-Hodgman clipping for masked quads | `e8005e07b` | Ported (KxRenderer) |
| `71b425b1a` | Bugfix | `e8005e07b` | Ported (KxRenderer) |
| `16106258c` | Bugfix | `e8005e07b` | Ported (KxRenderer) |
| `b64c4ca84` | Cleanup | `e8005e07b` | Ported (KxRenderer) |
| `ec6495102` | Bugfix | `e8005e07b` | Ported (KxRenderer) |
| `b804f9c5e` | Defaulting to nearest filtering | `e8005e07b` | Kept: NEAREST texture filtering (decision D3) |
| `f5f24861e` | Disabling double vertex buffering to avoid flickering | `e8005e07b` | Ported (KxRenderer) |
| `8b4596b80` | Texture memory tracking | — | Dropped: undone by `a2a4e01d6` and `b9aa21a2b` |
| `a2a4e01d6` | Reverting latest Bitmap and Tileset changes. Reducing vertex buffer size in KxRenderer | — | Dropped: revert; vertex buffer size superseded by `ed40ac15e` |
| `b9aa21a2b` | Removing texture memory tracking | — | Dropped: undoes `8b4596b80` |
| `01f692285` | Jeff Austin fixing a leak in CanvasGraphics where GPU memory wouldn't be released when ... | — | Already upstream: `5f09231ab` (openfl 9.5.0) |
| `c2fa7c909` | DisplayObject.__update call tracking | — | Dropped: debug counter only |
| `f73d82d20` | Cleanup | `e8005e07b`, `6e75bbac8` | Ported (texture version check). `KxRenderTarget` not carried: deleted later in the old fork |
| `45cf6d914` | Build fix | — | Dropped: build fix folded into `321b98a5c` |
| `676b2d474` | Removing DisplayObject.__renderTarget references | `e8005e07b` | Ported (KxRenderer) |
| `2b7793c0b` | Fixing a scrollRect bug | `e8005e07b` | Ported (KxRenderer) |
| `c97486b2d` | Trivial box clip when mask and DisplayObject are axis aligned | `e8005e07b` | Ported (KxRenderer) |
| `05809d0f1` | KxRenderer now draws Geometry objects in its pipeline | `e8005e07b`, `8ae63eb5a` | Ported (Geometry class + drawing) |
| `48847985c` | Jeff Austin: fixing an issue where DisplayObjectContainer.__cleanupRemovedChildren wasn... | `e8005e07b` | Ported (KxRenderer) |
| `b8b9f2b38` | Fixing an issue where objects with zero sized masks weren't masked at all | `e8005e07b` | Ported (KxRenderer) |
| `c5c4d4a8f` | Improving scale9Grid texture seams | — | Dropped: superseded by `19f4eb2c0` |
| `f43e8c7f9` | HACK: detect scale9Grid commands and enable additive composite operation | — | Dropped: superseded by `19f4eb2c0` |
| `19f4eb2c0` | Replacing the hacky scale9Grid fix with a less hacky one | `e8005e07b` | KxRenderer half ported. CanvasGraphics half (Animate scale9 workaround) not ported: openfl 9.5.2 draws scale9 shapes itself, and KxRenderer draws them as one quad, like openfl's own GL renderer |
| `5b162a181` | Jeff Austin: bind the default texture to unused units in a batch to avoid disposed text... | `e8005e07b` | Ported (KxRenderer) |
| `98eccdb12` | Jeff Austin: fixing a Graphics VRAM leak | `3d7824af9` | Cherry-picked |
| `efb154a11` | Fix __js__ deprecation. | — | Dropped: reverted by `1bb3551d5` |
| `d4f2eb992` | Rounding quad vertex coordinates before pushing to WebGL to reduce pixel snapping issues | `e8005e07b` | Kept: quad corners rounded to whole pixels (decision D4) |
| `1bb3551d5` | Revert "Fix __js__ deprecation." Incompatible with current version of HAXE BP is on. | — | Dropped: revert of `efb154a11` |
| `48900d866` | Adding shadowOffset and shadowColorTransform params to DisplayObject to support cheap s... | — | Dropped: `shadowOffset` unused by the game (decision D5) |
| `02bcef94e` | Parse both <br> and <sbr> as newlines so that the htmlText produced by Animate is parse... | `6bdc4b942` | Ported (HTMLParser moved to `openfl/text/_internal`) |
| `93e0cbf2c` | Add strokeThickness and strokeColorTransform params to DisplayObject to support a cheap... | — | Dropped: `strokeThickness` unused by the game (decision D5) |
| `ed40ac15e` | Increasing KxRenderer vertex buffer size | `e8005e07b` | Ported (KxRenderer) |
| `f4172ba1b` | Null check the __renderer exists, its currently not set when the context is set to canvas. | — | Dropped: null check belonged to the old BitmapData renderer code |
| `24aa284c0` | Add faster UTF8 decoding method for JavaScript. | `d392b85f5` | Ported, with a fix: decodes only the requested bytes |
| `3baffdabb` | Made a number of small adjustments to the TextField.hx class to correct the behaviour o... | — | Already upstream: `719aa4ed6`, `b08f9691f` (openfl 9.1.0) |
| `2915dfe73` | Made a number of small adjustments to the TextField.hx class to correct the behaviour o... | — | Dropped: duplicate of `3baffdabb` |
| `cdf762a67` | Null check the __renderer exists, its currently not set when the context is set to canvas. | — | Dropped: duplicate of `f4172ba1b` |
| `977c61347` | Added a compile conditional to prevent a js.syntax issue from breaking haxe 3 builds. | — | Dropped: Haxe 3 only |
| `099503180` | Added in conditional logic to switch between js.syntax.code and __js__ when working wit... | — | Dropped: Haxe 3 only |
| `285ba46e2` | Capture Lime Preloader errors and dispatch an ErrorEvent for the client to handle | — | Dropped: no game code listens for the preloader error event (decision D8) |
| `6f51232ad` | Adjusted the TextField class to respect the multiline property when replacing/inserting... | `a8cc9bc9a` | Cherry-picked |

Other Kixeye-only additions here (no old commit): KxRenderer is used only when built with `-Dkixeye`; `BitmapData.draw()` uses openfl 9.5.2's own canvas renderer (the old fork shared KxRenderer's, which left a released matrix in it).
