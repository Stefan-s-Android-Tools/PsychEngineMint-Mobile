package backend;

#if (flixel_animate && sys)
import animate.FlxAnimateAssets;
import animate.FlxAnimateAssets.AssetType;
import openfl.display.BitmapData;

/**
 * flixel-animate reads Adobe Animate texture atlases through `FlxAnimateAssets`, which only
 * looks at the packaged asset manifest (and at the filesystem on desktop). Mods and the game
 * folder extracted on Android are not part of the manifest, so their `Animation.json`,
 * `spritemap*.png` and `LIBRARY` files were never found and the characters fell back to their
 * sparrow atlas. These overrides add the same filesystem lookup `Paths` already does for every
 * other asset type; packaged assets keep being resolved first so vanilla behaviour is unchanged.
 */
class AnimateAssets
{
	static var installed:Bool = false;

	public static function ensureDiskSupport():Void
	{
		if (installed) return;
		installed = true;

		final packagedExists = FlxAnimateAssets.exists;
		final packagedText = FlxAnimateAssets.getText;
		final packagedBytes = FlxAnimateAssets.getBytes;
		final packagedBitmapData = FlxAnimateAssets.getBitmapData;
		final packagedList = FlxAnimateAssets.list;

		FlxAnimateAssets.exists = function(path:String, type:AssetType):Bool {
			return packagedExists(path, type) || onDisk(path);
		};

		FlxAnimateAssets.getText = function(path:String):String {
			var text:String = packagedText(path);
			if (text != null) return text;
			if (!onDisk(path)) return null;

			try {
				return File.getContent(path);
			}
			catch (e:Dynamic) {
				trace('AnimateAssets: could not read text "$path". ($e)');
				return null;
			}
		};

		FlxAnimateAssets.getBytes = function(path:String):haxe.io.Bytes {
			var bytes = packagedBytes(path);
			if (bytes != null) return bytes;
			if (!onDisk(path)) return null;

			try {
				return File.getBytes(path);
			}
			catch (e:Dynamic) {
				trace('AnimateAssets: could not read "$path". ($e)');
				return null;
			}
		};

		FlxAnimateAssets.getBitmapData = function(path:String):BitmapData {
			var bitmap:BitmapData = packagedBitmapData(path);
			if (bitmap != null) return bitmap;
			if (!onDisk(path)) return null;

			try {
				bitmap = BitmapData.fromFile(path);
			}
			catch (e:Dynamic) {
				trace('AnimateAssets: could not decode "$path". ($e)');
				return null;
			}

			if (bitmap == null) trace('AnimateAssets: could not decode "$path" (external storage).');
			return bitmap;
		};

		FlxAnimateAssets.list = function(path:String, ?type:AssetType, ?library:String, includeSubDirectories:Bool = false):Array<String> {
			var names:Array<String> = packagedList(path, type, library, includeSubDirectories);
			if (names != null && names.length > 0) return names;
			if (!onDisk(path) || !FileSystem.isDirectory(path)) return names != null ? names : [];

			try {
				names = FileSystem.readDirectory(path);
				if (includeSubDirectories) {
					var all:Array<String> = [];
					for (name in names.copy()) {
						if (FileSystem.isDirectory('$path/$name')) {
							for (child in FileSystem.readDirectory('$path/$name'))
								all.push('$name/$child');
						}
						else all.push(name);
					}
					names = all;
				}
			}
			catch (e:Dynamic) {
				trace('AnimateAssets: could not list "$path". ($e)');
				return names != null ? names : [];
			}
			return names;
		};
	}

	inline static function onDisk(path:String):Bool
	{
		if (path == null) return false;
		return FileSystem.exists(path);
	}
}
#end
