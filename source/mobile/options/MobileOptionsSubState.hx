package mobile.options;

import mobile.backend.MobileData;
import mobile.backend.MobileScaleMode;
import mobile.backend.StorageUtil;
import options.BaseOptionsMenu;
import options.Option;

class MobileOptionsSubState extends BaseOptionsMenu
{
	#if android
	var storageTypes:Array<String> = ["EXTERNAL", "EXTERNAL_OBB", "EXTERNAL_MEDIA"];
	var externalPaths:Array<String> = StorageUtil.checkExternalPaths(true);
	var lastStorageType:String;
	#end
	final exControlTypes:Array<String> = ["NONE", "SINGLE", "DOUBLE"];
	final hintOptions:Array<String> = ["Gradient", "No Gradient", "Hidden"];

	public function new()
	{
		#if android
		if (ClientPrefs.data.storageType == 'EXTERNAL_DATA')
			ClientPrefs.data.storageType = StorageType.DEFAULT;
		lastStorageType = ClientPrefs.data.storageType;

		for (path in externalPaths)
			if (path != null && path.length > 0 && !storageTypes.contains(path))
				storageTypes.push(path);
		#end

		super('Mobile Options', 'Mobile Options Menu');

		var option:Option = new Option('Extra Controls',
			'Select how many extra buttons you prefer to have.\nThey can be used for mechanics with LUA or HScript.', 'extraButtons', STRING,
			exControlTypes);
		addOption(option);

		option = new Option('Mobile Controls Opacity',
			'Selects the opacity for the mobile buttons (careful not to put it at 0 and lose track of your buttons).', 'controlsAlpha', PERCENT);
		option.scrollSpeed = 1;
		option.minValue = 0.001;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = (mod:Float, hold:Bool) -> {
			var state:MusicBeatSubstate = MusicBeatState.getState();
			if (state != null) {
				if (state.mobileControls != null && state.mobileControls.instance != null)
					state.mobileControls.instance.alpha = ClientPrefs.data.controlsAlpha;
				else if (state.touchPad != null)
					state.touchPad.alpha = ClientPrefs.data.controlsAlpha;
			}
			ClientPrefs.toggleVolumeKeys();
		};
		addOption(option);

		#if mobile
		option = new Option('Allow Phone Screensaver',
			'If checked, the phone will sleep after going inactive for few seconds.\n(The time depends on your phone\'s options)', 'screensaver', BOOL);
		option.onChange = (mod:Float, hold:Bool) -> lime.system.System.allowScreenTimeout = ClientPrefs.data.screensaver;
		addOption(option);

		option = new Option('Wide Screen Mode',
			'If checked, the game will stretch to fill your whole screen. (WARNING: Can result in bad visuals & break some mods that resize the game/cameras)',
			'wideScreen', BOOL);
		option.onChange = (mod:Float, hold:Bool) -> FlxG.scaleMode = new MobileScaleMode();
		addOption(option);
		#end

		if (MobileData.mode == 3)
		{
			option = new Option('Hitbox Design', 'Choose how your hitbox should look like.', 'hitboxType', STRING, hintOptions);
			addOption(option);

			option = new Option('Hitbox Position', 'If checked, the hitbox will be put at the bottom of the screen, otherwise will stay at the top.',
				'hitbox2', BOOL);
			addOption(option);
		}

		option = new Option('Dynamic Controls Color',
			'If checked, the mobile controls color will be set to the notes color in your settings.\n(has effect during gameplay only)', 'dynamicColors',
			BOOL);
		addOption(option);

		#if android
		option = new Option('Storage Type', 'Which folder Psych Engine should use?\nMods, saves and crash logs are moved to the new folder and the game restarts.', 'storageType', STRING,
			storageTypes);
		addOption(option);
		#end
	}

	#if android
	function onStorageChange():Void
	{
		File.saveContent(lime.system.System.applicationStorageDirectory + 'storagetype.txt', ClientPrefs.data.storageType);

		var oldPath:String = lastStorageType == 'EXTERNAL_DATA' ? StorageType.legacyDataPath() : StorageType.fromStrForce(lastStorageType);
		var newPath:String = StorageType.fromStrForce(ClientPrefs.data.storageType);
		if (!oldPath.endsWith('/')) oldPath += '/';
		if (!newPath.endsWith('/')) newPath += '/';

		if (oldPath == newPath)
			return;

		StorageUtil.createDirectories(newPath);
		// only delete the old folder once the data is really there
		if (StorageUtil.copyContents(oldPath, newPath, ['mods', 'saves', 'crash', 'logs']) && StorageUtil.isWritable(newPath))
			Sys.command('rm', ['-rf', oldPath]);
		else
			trace('Could not move "$oldPath" to "$newPath", keeping both folders.');
	}
	#end

	override public function destroy()
	{
		super.destroy();
		#if android
		if (ClientPrefs.data.storageType != lastStorageType)
		{
			onStorageChange();
			CoolUtil.showPopUp('Storage Type has been changed and you need to restart the game!!\nPress OK to close the game.', 'Notice!');
			lime.system.System.exit(0);
		}
		#end
	}
}
