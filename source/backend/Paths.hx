package backend;

#if flixel_animate
import animate.FlxAnimateFrames;
#end

import flixel.graphics.frames.FlxFrame.FlxFrameAngle;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxRect;
import flixel.system.FlxAssets;

import openfl.display.BitmapData;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.system.System;
import openfl.geom.Rectangle;

import lime.utils.Assets;
import flash.media.Sound;

import haxe.Json;

#if MODS_ALLOWED
import backend.Mods;
#end

@:access(openfl.display.BitmapData)
class Paths
{
	inline public static var SOUND_EXT = "ogg";
	inline public static var VIDEO_EXT = "mp4";

	public static function excludeAsset(key:String) {
		if (!dumpExclusions.contains(key))
			dumpExclusions.push(key);
	}

	public static var dumpExclusions:Array<String> = ['assets/shared/music/freakyMenu.$SOUND_EXT', 'assets/shared/mobile/images/touchpad/bg.png'];
	// haya I love you for the base cache dump I took to the max
	public static function clearUnusedMemory()
	{
		// clear non local assets in the tracked assets list
		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key))
			{
				destroyGraphic(currentTrackedAssets.get(key)); // get rid of the graphic
				currentTrackedAssets.remove(key); // and remove the key from local cache map
			}
		}

		// run the garbage collector for good measure lmfao
		System.gc();
	}

	// define the locally tracked assets
	public static var localTrackedAssets:Array<String> = [];

	@:access(flixel.system.frontEnds.BitmapFrontEnd._cache)
	public static function clearStoredMemory()
	{
		// clear anything not in the tracked assets list
		for (key in FlxG.bitmap._cache.keys())
		{
			if (!currentTrackedAssets.exists(key))
				destroyGraphic(FlxG.bitmap.get(key));
		}

		// clear all sounds that are cached
		for (key => asset in currentTrackedSounds)
		{
			if (!localTrackedAssets.contains(key) && !dumpExclusions.contains(key) && asset != null)
			{
				Assets.cache.clear(key);
				currentTrackedSounds.remove(key);
			}
		}
		// flags everything to be cleared out next unused memory clear
		localTrackedAssets = [];
		#if !html5 openfl.Assets.cache.clear("songs"); #end
	}

	public static function freeGraphicsFromMemory()
	{
		var protectedGfx:Array<FlxGraphic> = [];
		function checkForGraphics(spr:Dynamic)
		{
			try
			{
				var grp:Array<Dynamic> = Reflect.getProperty(spr, 'members');
				if(grp != null)
				{
					//trace('is actually a group');
					for (member in grp)
					{
						checkForGraphics(member);
					}
					return;
				}
			}

			//trace('check...');
			try
			{
				var gfx:FlxGraphic = Reflect.getProperty(spr, 'graphic');
				if(gfx != null)
				{
					protectedGfx.push(gfx);
					//trace('gfx added to the list successfully!');
				}
			}
			//catch(haxe.Exception) {}
		}

		for (member in FlxG.state.members)
			checkForGraphics(member);

		if(FlxG.state.subState != null)
			for (member in FlxG.state.subState.members)
				checkForGraphics(member);

		for (key in currentTrackedAssets.keys())
		{
			// if it is not currently contained within the used local assets
			if (!dumpExclusions.contains(key))
			{
				var graphic:FlxGraphic = currentTrackedAssets.get(key);
				if(!protectedGfx.contains(graphic))
				{
					destroyGraphic(graphic); // get rid of the graphic
					currentTrackedAssets.remove(key); // and remove the key from local cache map
					//trace('deleted $key');
				}
			}
		}
	}

	inline static function destroyGraphic(graphic:FlxGraphic)
	{
		// free some gpu memory
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();
		FlxG.bitmap.remove(graphic);
	}

	static public var currentLevel:String;
	static public function setCurrentLevel(name:String)
		currentLevel = name.toLowerCase();

	/**
	 * Whether `path` exists on disk or inside the packaged assets. Android ships the game data
	 * inside the APK, so a plain `FileSystem.exists` is not enough on mobile.
	 */
	public static function exists(path:String):Bool
	{
		if (path == null || path.length == 0)
			return false;

		#if sys
		if (FileSystem.exists(path))
			return true;
		#end
		return OpenFlAssets.exists(path);
	}

	public static function getPath(file:String, ?type:AssetType = TEXT, ?parentfolder:String, ?modsAllowed:Bool = true):String
	{
		#if MODS_ALLOWED
		if(modsAllowed)
		{
			var customFile:String = file;
			if (parentfolder != null) customFile = '$parentfolder/$file';

			var modded:String = modFolders(customFile);
			if(FileSystem.exists(modded)) return modded;
		}
		#end

		if (parentfolder != null)
		{
			if (parentfolder == "mobile")
				return getSharedPath('mobile/$file');

			return getFolderPath(file, parentfolder);
		}

		if (currentLevel != null && currentLevel != 'shared')
		{
			var levelPath = getFolderPath(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}
		
		if (exists(file)) return file;
		
		return getSharedPath(file);
	}

	inline static public function getFolderPath(file:String, folder = "shared")
		return 'assets/$folder/$file';

	inline public static function getSharedPath(file:String = '')
		return 'assets/shared/$file';

	/**
	 * Lists the files inside a directory, falling back to the embedded
	 * assets list when the folder does not exist on the filesystem.
	 */
	public static function readDirectory(directory:String):Array<String>
	{
		var files:Array<String> = [];

		#if sys
		if (FileSystem.exists(directory) && FileSystem.isDirectory(directory))
			return FileSystem.readDirectory(directory);
		#end

		for (path in OpenFlAssets.list())
		{
			if (path.startsWith('$directory/') && !files.contains(path))
				files.push(path);
		}

		return files;
	}

	inline static public function txt(key:String, ?folder:String)
		return getPath('data/$key.txt', TEXT, folder, true);

	inline static public function xml(key:String, ?folder:String)
		return getPath('data/$key.xml', TEXT, folder, true);

	inline static public function json(key:String, ?folder:String)
		return getPath('data/$key.json', TEXT, folder, true);

	inline static public function shaderFragment(key:String, ?folder:String)
		return getPath('shaders/$key.frag', TEXT, folder, true);

	inline static public function shaderVertex(key:String, ?folder:String)
		return getPath('shaders/$key.vert', TEXT, folder, true);

	inline static public function lua(key:String, ?folder:String)
		return getPath('$key.lua', TEXT, folder, true);

	static public function video(key:String)
	{
		#if MODS_ALLOWED
		var file:String = modsVideo(key);
		if(FileSystem.exists(file)) return file;
		#end
		return 'assets/videos/$key.$VIDEO_EXT';
	}

	inline static public function sound(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('sounds/$key', modsAllowed);

	inline static public function music(key:String, ?modsAllowed:Bool = true):Sound
		return returnSound('music/$key', modsAllowed);

	inline static public function inst(song:String, ?modsAllowed:Bool = true):Sound
		return returnSound('${formatToSongPath(song)}/Inst', 'songs', modsAllowed);

	inline static public function voices(song:String, postfix:String = null, ?modsAllowed:Bool = true):Sound
	{
		var songKey:String = '${formatToSongPath(song)}/Voices';
		if(postfix != null) songKey += '-' + postfix;
		//trace('songKey test: $songKey');
		return returnSound(songKey, 'songs', modsAllowed, false);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?modsAllowed:Bool = true)
		return sound(key + FlxG.random.int(min, max), modsAllowed);

	public static var currentTrackedAssets:Map<String, FlxGraphic> = [];

	/** GPU texture size limit, filled in by `Main` from the Android GL context (0 = unknown). */
	public static var maxTextureSize:Int = 0;
	static public function image(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxGraphic
	{
		key = Language.getFileTranslation('images/$key') + '.png';
		var bitmap:BitmapData = null;
		if (currentTrackedAssets.exists(key))
		{
			localTrackedAssets.push(key);
			return currentTrackedAssets.get(key);
		}
		return cacheBitmap(key, parentFolder, bitmap, allowGPU);
	}
	
	public static function gpuCacheBitmap(bitmap:BitmapData):Void
	{
		if (!ClientPrefs.data.cacheOnGPU || bitmap.image == null) return;
		
		bitmap.lock();
		if (bitmap.__texture == null)
		{
			bitmap.image.premultiplied = true;
			bitmap.getTexture(FlxG.stage.context3D);
		}
		bitmap.getSurface();
		bitmap.disposeImage();
		bitmap.image.data = null;
		bitmap.image = null;
		bitmap.readable = true;
	}

	public static function cacheBitmap(key:String, ?parentFolder:String = null, ?bitmap:BitmapData, ?allowGPU:Bool = true):FlxGraphic
	{
		if (bitmap == null)
		{
			var file:String = getPath(key, IMAGE, parentFolder, true);
			var source:String = 'missing';

			#if (MODS_ALLOWED && sys)
			if (FileSystem.exists(file))
			{
				source = 'external storage';
				// an existing file can still fail to decode (corrupt or unsupported bit depth)
				try bitmap = BitmapData.fromFile(file)
				catch (e:Dynamic) trace('Could not decode image ${describeFile(file)}. ($e)');
			}
			#end

			if (bitmap == null && OpenFlAssets.exists(file, IMAGE))
			{
				source = 'package';
				bitmap = OpenFlAssets.getBitmapData(file);
			}

			if (bitmap == null)
			{
				trace('IMAGE NOT FOUND: key: $key | path: $file | source: $source');
				return null;
			}

			// OpenGL ES 2.0 only guarantees 2048px, so an oversized mod spritemap can fail to upload
			if (maxTextureSize > 0 && (bitmap.width > maxTextureSize || bitmap.height > maxTextureSize))
				trace('IMAGE TOO LARGE for this GPU: $file (${bitmap.width}x${bitmap.height}, limit ${maxTextureSize}px)');
		}

		if (allowGPU) gpuCacheBitmap(bitmap);

		var graph:FlxGraphic = FlxGraphic.fromBitmapData(bitmap, false, key);
		graph.persist = true;
		graph.destroyOnNoUse = false;

		currentTrackedAssets.set(key, graph);
		localTrackedAssets.push(key);
		return graph;
	}

	/**
	 * Readable form of a failed load: path, where it would come from and its size.
	 */
	public static function describeFile(path:String):String
	{
		#if sys
		if (FileSystem.exists(path))
		{
			var size:String = 'unknown size';
			try size = flixel.util.FlxStringUtil.formatBytes(FileSystem.stat(path).size)
			catch (e:Dynamic) {}
			return '"' + path + '" (external storage, ' + size + ')';
		}
		#end
		return '"' + path + '" (not on disk, package lookup only)';
	}

	inline static public function getTextFromFile(key:String, ?ignoreMods:Bool = false):String
	{
		var path:String = getPath(key, TEXT, null, !ignoreMods);
		#if sys
		if (FileSystem.exists(path))
			return File.getContent(path);
		#end
		return (OpenFlAssets.exists(path, TEXT)) ? OpenFlAssets.getText(path) : null;
	}

	inline static public function font(key:String, embedded:Bool = true)
	{
		var folderKey:String = Language.getFileTranslation('fonts/$key');
		#if (MODS_ALLOWED && sys)
		var file:String = modFolders(folderKey);
		if (FileSystem.exists(file)) return file;
		#end
		if (OpenFlAssets.exists('assets/$folderKey')) return OpenFlAssets.getFont('assets/$folderKey').fontName;
		return 'assets/$folderKey';
	}

	public static function fileExists(key:String, type:AssetType, ?ignoreMods:Bool = false, ?parentFolder:String = null)
	{
		#if MODS_ALLOWED
		if(!ignoreMods)
		{
			var modKey:String = key;
			if(parentFolder == 'songs') modKey = 'songs/$key';

			for(mod in Mods.getGlobalMods())
				if (FileSystem.exists(mods('$mod/$modKey')))
					return true;

			if (FileSystem.exists(mods(Mods.currentModDirectory + '/' + modKey)) || FileSystem.exists(mods(modKey)))
				return true;
		}
		#end
		return (OpenFlAssets.exists(getPath(key, type, parentFolder, false)));
	}

	static public function getAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) return null;

		// The description has to follow the same path rules as the image: a mod that ships its own
		// atlas must never be paired with the frame rectangles of a sibling or of the base game.
		var text:String = readAtlasText(key, '.xml', parentFolder);
		if (text != null) return FlxAtlasFrames.fromSparrow(imageLoaded, text);

		text = readAtlasText(key, '.json', parentFolder);
		if (text != null) return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, text);

		return getPackerAtlas(key, parentFolder);
	}
	
	static public function getMultiAtlas(keys:Array<String>, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim(), parentFolder, allowGPU);
		if (parentFrames == null) {
			for (i in 1...keys.length) {
				parentFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if (parentFrames != null) break;
			}
			if (parentFrames == null) return null;
		}
		if(keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), parentFolder, allowGPU);
				if(extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	inline static public function getSparrowAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) return null;

		var text:String = getAtlasText(key, '.xml', parentFolder);
		if (text == null) return new FlxAtlasFrames(imageLoaded);
		return FlxAtlasFrames.fromSparrow(imageLoaded, text);
	}

	inline static public function getPackerAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) return null;

		var text:String = getAtlasText(key, '.txt', parentFolder);
		if (text == null) return new FlxAtlasFrames(imageLoaded);
		return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, text);
	}

	inline static public function getAsepriteAtlas(key:String, ?parentFolder:String = null, ?allowGPU:Bool = true):FlxAtlasFrames
	{
		var imageLoaded:FlxGraphic = image(key, parentFolder, allowGPU);
		if (imageLoaded == null) return null;

		var text:String = getAtlasText(key, '.json', parentFolder);
		if (text == null) return new FlxAtlasFrames(imageLoaded);
		return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, text);
	}

	/**
	 * Reads the description of an atlas from the same folder as its image. A mod that ships a
	 * new image without its description would otherwise keep the frame rectangles of the base
	 * game, which shows up as shifted or cut sprites.
	 */
	static function getAtlasText(key:String, extension:String, ?parentFolder:String):String
	{
		var text:String = readAtlasText(key, extension, parentFolder);
		if (text == null)
			trace('Missing atlas description "${getPath('images/$key' + extension, TEXT, parentFolder)}" for "$key".');
		return text;
	}

	static function readAtlasText(key:String, extension:String, ?parentFolder:String):String
	{
		var path:String = getPath(Language.getFileTranslation('images/$key') + extension, TEXT, parentFolder);
		var text:String = getTextFromFile(path);

		if (text == null || StringTools.trim(text).length < 1) return null;
		return text;
	}

	inline static public function formatToSongPath(path:String) {
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static var currentTrackedSounds:Map<String, Sound> = [];
	public static function returnSound(key:String, ?path:String, ?modsAllowed:Bool = true, ?beepOnNull:Bool = true)
	{
		var file:String = getPath(Language.getFileTranslation(key) + '.$SOUND_EXT', SOUND, path, modsAllowed);

		//trace('precaching sound: $file');
		if(!currentTrackedSounds.exists(file))
		{
			var loaded:Sound = null;
			#if (MODS_ALLOWED && sys)
			if(FileSystem.exists(file))
			{
				// an existing file can still fail to decode (corrupt, wrong codec or an
				// unsupported sample rate); never let that take the state down with it
				try loaded = Sound.fromFile(file)
				catch (e:Dynamic) trace('Could not decode sound ${describeFile(file)}. ($e)');
			}
			#end
			if(loaded == null && OpenFlAssets.exists(file, SOUND))
				loaded = OpenFlAssets.getSound(file);

			if(loaded != null)
				currentTrackedSounds.set(file, loaded);
			else if(beepOnNull)
			{
				trace('SOUND NOT FOUND: $key, PATH: $path');
				FlxG.log.error('SOUND NOT FOUND: $key, PATH: $path');
				return FlxAssets.getSoundAddExtension('flixel/sounds/beep');
			}
		}
		localTrackedAssets.push(file);
		return currentTrackedSounds.get(file);
	}

	#if MODS_ALLOWED
	inline static public function mods(key:String = '')
		return 'mods/' + key;

	inline static public function modsJson(key:String)
		return modFolders('data/' + key + '.json');

	inline static public function modsVideo(key:String)
		return modFolders('videos/' + key + '.' + VIDEO_EXT);

	inline static public function modsSounds(path:String, key:String)
		return modFolders(path + '/' + key + '.' + SOUND_EXT);

	inline static public function modsImages(key:String)
		return modFolders('images/' + key + '.png');

	inline static public function modsXml(key:String)
		return modFolders('images/' + key + '.xml');

	inline static public function modsTxt(key:String)
		return modFolders('images/' + key + '.txt');

	inline static public function modsImagesJson(key:String)
		return modFolders('images/' + key + '.json');

	static public function modFolders(key:String)
	{
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var fileToCheck:String = mods(Mods.currentModDirectory + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}

		for(mod in Mods.getGlobalMods())
		{
			var fileToCheck:String = mods(mod + '/' + key);
			if(FileSystem.exists(fileToCheck))
				return fileToCheck;
		}
		return 'mods/' + key;
	}
	#end
	
	#if flixel_animate
	inline static public function animate(key:String, ?parentFolder:String):String
		return getPath('images/$key/Animation.json', parentFolder);
	
	public static function loadAnimateAtlas(spr:FlxAnimate, path:String):Bool {
		final atlas:FlxAnimateFrames = getAnimateAtlas(path);
		
		spr.frames = atlas;
		
		return (atlas != null);
	}
	
	public static function getAnimateAtlas(key:String, ?parentFolder:String, allowGPU:Bool = true):FlxAnimateFrames {
		// mods and the game folder extracted on Android live outside the packaged manifest
		backend.AnimateAssets.ensureDiskSupport();

		final path:String = animate(key, parentFolder);

		if (! #if (MODS_ALLOWED && sys) FileSystem #else OpenFlAssets #end.exists(path)) {
			trace('ANIMATION JSON NOT FOUND: $key, PATH: $path');

			return null;
		}

		final folder:String = path.substring(0, path.length - '/Animation.json'.length); // idk it trips if i dont do that

		// `spritemaps` and `metadata` have to stay null so the settings land on their own argument
		var animateFrames:FlxAnimateFrames = FlxAnimateFrames.fromAnimate(folder, null, null, null, false, {cacheOnLoad: true});
		
		// trace('$path, $folder -> $animateFrames');
		
		if (animateFrames != null) {
			if (allowGPU) {
				for (spritemap in @:privateAccess cast(animateFrames.parent, FlxAnimateSpritemapCollection).spritemaps) {
					if (spritemap.bitmap != null)
						gpuCacheBitmap(spritemap.bitmap);
				}
			}
			
			return animateFrames;
		}
		
		return null;
	}
	#end
}
