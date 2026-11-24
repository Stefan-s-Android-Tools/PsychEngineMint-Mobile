package mobile.backend;

import lime.system.System as LimeSystem;
import haxe.io.Path;
import haxe.Exception;

/**
 * Storage helpers for mobile platforms.
 * @author Mihai Alexandru (M.A. Jigsaw), Karim Akra and Lily Ross (mcagabe19)
 */
class StorageUtil
{
	#if sys
	/**
         * Root directory, used for handling the saved storage type and path.
	*/
	public static final rootDir:String = LimeSystem.applicationStorageDirectory;

	public static function getStorageDirectory(?force:Bool = false):String
	{
		var daPath:String = '';
		#if android
		if (!FileSystem.exists(rootDir + 'storagetype.txt'))
			File.saveContent(rootDir + 'storagetype.txt', ClientPrefs.data == null ? StorageType.DEFAULT : ClientPrefs.data.storageType);
		var curStorageType:String = File.getContent(rootDir + 'storagetype.txt');
		daPath = force ? StorageType.fromStrForce(curStorageType) : StorageType.fromStr(curStorageType);
		#elseif ios
		daPath = LimeSystem.documentsDirectory;
		#else
		daPath = rootDir;
		#end

		return Path.addTrailingSlash(daPath);
	}

	public static function createDirectories(directory:String):Void
	{
		try
		{
			if (FileSystem.exists(directory) && FileSystem.isDirectory(directory))
				return;
		}
		catch (e:Exception)
		{
			trace('Something went wrong while looking at directory. (${e.message})');
		}

		var total:String = '';
		if (directory.substr(0, 1) == '/')
			total = '/';

		var parts:Array<String> = directory.split('/');
		if (parts.length > 0 && parts[0].indexOf(':') > -1)
			parts.shift();

		for (part in parts)
		{
			if (part != '.' && part != '')
			{
				if (total != '' && total != '/')
					total += '/';

				total += part;

				try
				{
					if (!FileSystem.exists(total))
						FileSystem.createDirectory(total);
				}
				catch (e:Exception)
					trace('Error while creating directory. (${e.message})');
			}
		}
	}

	public static function saveContent(fileName:String, fileData:String, ?alert:Bool = true):Void
	{
		try
		{
			if (!FileSystem.exists('saves'))
				FileSystem.createDirectory('saves');

			File.saveContent('saves/$fileName', fileData);
			if (alert)
				CoolUtil.showPopUp('$fileName has been saved.', "Success!");
		}
		catch (e:Exception)
			if (alert)
				CoolUtil.showPopUp('$fileName couldn\'t be saved.\n(${e.message})', "Error!")
			else
				trace('$fileName couldn\'t be saved. (${e.message})');
	}

	public static function checkExternalPaths(?splitStorage = false):Array<String>
	{
		var paths:Array<String> = [];
		try
		{
			for (path in FileSystem.readDirectory('/storage'))
			{
				if (path == 'emulated' || path == 'self')
					continue;
				paths.push(splitStorage ? path : '/storage/$path');
			}
		}
		catch (e:Exception)
			trace('Could not read the external storage paths. (${e.message})');

		return paths;
	}

	public static function getExternalDirectory(externalDir:String):String
	{
		var daPath:String = '';
		for (path in checkExternalPaths())
			if (path.contains(externalDir))
				daPath = path;

		daPath = Path.addTrailingSlash(daPath.endsWith("\n") ? daPath.substr(0, daPath.length - 1) : daPath);
		return daPath;
	}

	/**
	 * Checks whether `directory` can be written to. Used to fall back to the app data
	 * folder when the external one is not accessible (missing MANAGE_EXTERNAL_STORAGE).
	 */
	public static function isWritable(directory:String):Bool
	{
		final probe:String = Path.addTrailingSlash(directory) + '.write_test';
		try
		{
			File.saveContent(probe, '');
			FileSystem.deleteFile(probe);
			return true;
		}
		catch (e:Exception)
		{
			trace('"$directory" is not writable. (${e.message})');
			return false;
		}
	}

	/**
	 * Copies `from` into `to`, recursively. When `only` is set, only those entries are copied.
	 * @return false when at least one entry could not be copied.
	 */
	public static function copyContents(from:String, to:String, ?only:Array<String>):Bool
	{
		from = Path.addTrailingSlash(from);
		to = Path.addTrailingSlash(to);

		if (!FileSystem.exists(from) || !FileSystem.isDirectory(from))
			return false;

		var ok:Bool = true;
		final names:Array<String> = only ?? FileSystem.readDirectory(from);
		for (name in names)
		{
			final src:String = from + name;
			final dst:String = to + name;
			try
			{
				if (!FileSystem.exists(src))
					continue;

				if (FileSystem.isDirectory(src))
					ok = copyDirectory(src, dst) && ok;
				else
					File.copy(src, dst);
			}
			catch (e:Exception)
			{
				trace('Could not copy "$src" to "$dst". (${e.message})');
				ok = false;
			}
		}
		return ok;
	}

	static function copyDirectory(from:String, to:String):Bool
	{
		var ok:Bool = true;
		try
		{
			if (!FileSystem.exists(to))
				FileSystem.createDirectory(to);

			for (name in FileSystem.readDirectory(from))
			{
				final src:String = Path.addTrailingSlash(from) + name;
				final dst:String = Path.addTrailingSlash(to) + name;
				if (FileSystem.isDirectory(src))
					ok = copyDirectory(src, dst) && ok;
				else
					File.copy(src, dst);
			}
		}
		catch (e:Exception)
		{
			trace('Could not copy "$from" to "$to". (${e.message})');
			ok = false;
		}
		return ok;
	}
	#end
}

#if android
@:runtimeValue
enum abstract StorageType(String) from String to String
{
	public static inline var DEFAULT:String = "EXTERNAL";

	var EXTERNAL_OBB = "EXTERNAL_OBB";
	var EXTERNAL_MEDIA = "EXTERNAL_MEDIA";
	var EXTERNAL = "EXTERNAL";

	static function getAndroidRoot():String
	{
		var dir:String = LimeSystem.applicationStorageDirectory;
		var index:Int = dir.indexOf('/Android/');
		return index > 0 ? dir.substr(0, index) : '/storage/emulated/0';
	}

	static function getPackageName():String
		return lime.app.Application.current.meta.get('packageName');

	static function getFileMeta():String
		return lime.app.Application.current.meta.get('file');

	public static function legacyDataPath():String
		return '${getAndroidRoot()}/Android/data/${getPackageName()}/files';

	public static function fromStr(str:String):StorageType
	{
		final root:String = getAndroidRoot();

		return switch (str)
		{
			case "EXTERNAL_DATA": '$root/.${getFileMeta()}'; // legacy value, data dir is gone
			case "EXTERNAL_OBB": '$root/Android/obb/${getPackageName()}';
			case "EXTERNAL_MEDIA": '$root/Android/media/${getPackageName()}';
			case "EXTERNAL": '$root/.${getFileMeta()}';
			default: '$root/.${str}';
		}
	}

	public static function fromStrForce(str:String):StorageType
	{
		final root:String = getAndroidRoot();

		return switch (str)
		{
			case "EXTERNAL_DATA": '$root/.${getFileMeta()}'; // legacy value, data dir is gone
			case "EXTERNAL_OBB": '$root/Android/obb/${getPackageName()}';
			case "EXTERNAL_MEDIA": '$root/Android/media/${getPackageName()}';
			case "EXTERNAL": '$root/.${getFileMeta()}';
			default: '$root/.${str}';
		}
	}
}
#end
