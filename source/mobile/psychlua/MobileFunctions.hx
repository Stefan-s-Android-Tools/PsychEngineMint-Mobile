package mobile.psychlua;

#if LUA_ALLOWED
import lime.ui.Haptic;
import scripting.lua.FunkinLua;
import mobile.backend.MobileData;
import mobile.backend.TouchFunctions;
#if android import mobile.backend.PsychJNI; #end

/**
 * Exposes the mobile controls API to Lua scripts.
 * @author Karim Akra and Lily Ross (mcagabe19)
 */
class MobileFunctions {
	public static function implement() {
		FunkinLua.registerFunction("extraButtonPressed", function(button:String) {
			button = button.toLowerCase();
			var state = MusicBeatSubstate.getInputTarget();
			if (state != null && state.mobileControls != null) {
				return switch (button) {
					case 'second': state.mobileControls.buttonExtra2.pressed;
					default: state.mobileControls.buttonExtra.pressed;
				};
			}
			return false;
		});

		FunkinLua.registerFunction("extraButtonJustPressed", function(button:String) {
			button = button.toLowerCase();
			var state = MusicBeatSubstate.getInputTarget();
			if (state != null && state.mobileControls != null) {
				return switch (button) {
					case 'second': state.mobileControls.buttonExtra2.justPressed;
					default: state.mobileControls.buttonExtra.justPressed;
				};
			}
			return false;
		});

		FunkinLua.registerFunction("extraButtonJustReleased", function(button:String) {
			button = button.toLowerCase();
			var state = MusicBeatSubstate.getInputTarget();
			if (state != null && state.mobileControls != null) {
				return switch (button) {
					case 'second': state.mobileControls.buttonExtra2.justReleased;
					default: state.mobileControls.buttonExtra.justReleased;
				};
			}
			return false;
		});

		FunkinLua.registerFunction("vibrate", function(?duration:Int, ?period:Int) {
			if (duration == null)
				return FunkinLua.luaTrace('vibrate: No duration specified.');
			else if (period == null)
				period = 0;
			return Haptic.vibrate(period, duration);
		});

		FunkinLua.registerFunction("addTouchPad", function(DPadMode:String, ActionMode:String) {
			PlayState.instance.makeLuaTouchPad(DPadMode, ActionMode);
			PlayState.instance.addLuaTouchPad();
		});

		FunkinLua.registerFunction("removeTouchPad", function() {
			PlayState.instance.removeLuaTouchPad();
		});

		FunkinLua.registerFunction("addTouchPadCamera", function() {
			if (PlayState.instance.luaTouchPad == null) {
				FunkinLua.luaTrace('addTouchPadCamera: Virtual Pad does not exist.');
				return;
			}
			PlayState.instance.addLuaTouchPadCamera();
		});

		FunkinLua.registerFunction("touchPadJustPressed", function(button:Dynamic):Bool {
			if (PlayState.instance.luaTouchPad == null)
				return false;
			return PlayState.instance.luaTouchPadJustPressed(button);
		});

		FunkinLua.registerFunction("touchPadPressed", function(button:Dynamic):Bool {
			if (PlayState.instance.luaTouchPad == null)
				return false;
			return PlayState.instance.luaTouchPadPressed(button);
		});

		FunkinLua.registerFunction("touchPadJustReleased", function(button:Dynamic):Bool {
			if (PlayState.instance.luaTouchPad == null)
				return false;
			return PlayState.instance.luaTouchPadJustReleased(button);
		});

		FunkinLua.registerFunction("touchJustPressed", TouchFunctions.touchJustPressed);
		FunkinLua.registerFunction("touchPressed", TouchFunctions.touchPressed);
		FunkinLua.registerFunction("touchJustReleased", TouchFunctions.touchJustReleased);

		FunkinLua.registerFunction("touchPressedObject", function(object:String):Bool {
			var obj = PlayState.instance.getLuaObject(object);
			if (obj == null) {
				FunkinLua.luaTrace('touchPressedObject: $object does not exist.');
				return false;
			}
			return TouchFunctions.touchOverlapObject(obj) && TouchFunctions.touchPressed;
		});

		FunkinLua.registerFunction("touchJustPressedObject", function(object:String):Bool {
			var obj = PlayState.instance.getLuaObject(object);
			if (obj == null) {
				FunkinLua.luaTrace('touchJustPressedObject: $object does not exist.');
				return false;
			}
			return TouchFunctions.touchOverlapObject(obj) && TouchFunctions.touchJustPressed;
		});

		FunkinLua.registerFunction("touchJustReleasedObject", function(object:String):Bool {
			var obj = PlayState.instance.getLuaObject(object);
			if (obj == null) {
				FunkinLua.luaTrace('touchJustReleasedObject: $object does not exist.');
				return false;
			}
			return TouchFunctions.touchOverlapObject(obj) && TouchFunctions.touchJustReleased;
		});

		FunkinLua.registerFunction("touchOverlapsObject", function(object:String):Bool {
			var obj = PlayState.instance.getLuaObject(object);
			if (obj == null) {
				FunkinLua.luaTrace('touchOverlapsObject: $object does not exist.');
				return false;
			}
			return TouchFunctions.touchOverlapObject(obj);
		});

		#if android
		FunkinLua.registerFunction("backJustPressed", () -> FlxG.android.justPressed.BACK);
		FunkinLua.registerFunction("backPressed", () -> FlxG.android.pressed.BACK);
		FunkinLua.registerFunction("backJustReleased", () -> FlxG.android.justReleased.BACK);

		FunkinLua.registerFunction("menuJustPressed", () -> FlxG.android.justPressed.MENU);
		FunkinLua.registerFunction("menuPressed", () -> FlxG.android.pressed.MENU);
		FunkinLua.registerFunction("menuJustReleased", () -> FlxG.android.justReleased.MENU);

		FunkinLua.registerFunction("getCurrentOrientation", () -> PsychJNI.getCurrentOrientationAsString());

		FunkinLua.registerFunction("setOrientation", function(?hint:String) {
			if (hint == null)
				return FunkinLua.luaTrace('setOrientation: No orientation specified.');

			var orientation:Null<String> = switch (hint.toLowerCase()) {
				case 'portrait': 'Portrait';
				case 'portraitupsidedown' | 'upsidedownportrait' | 'upsidedown': 'PortraitUpsideDown';
				case 'landscapeleft' | 'leftlandscape': 'LandscapeLeft';
				case 'landscaperight' | 'rightlandscape' | 'landscape': 'LandscapeRight';
				default: null;
			};

			if (orientation == null)
				return FunkinLua.luaTrace('setOrientation: Invalid orientation "$hint".');

			PsychJNI.setOrientation(FlxG.stage.stageWidth, FlxG.stage.stageHeight, false, orientation);
		});

		FunkinLua.registerFunction("isScreenKeyboardShown", () -> PsychJNI.isScreenKeyboardShown());

		FunkinLua.registerFunction("clipboardHasText", () -> PsychJNI.clipboardHasText());
		FunkinLua.registerFunction("clipboardGetText", () -> PsychJNI.clipboardGetText());

		FunkinLua.registerFunction("clipboardSetText", function(?text:String) {
			if (text == null)
				return FunkinLua.luaTrace('clipboardSetText: No text specified.');
			PsychJNI.clipboardSetText(text);
		});

		FunkinLua.registerFunction("manualBackButton", () -> PsychJNI.manualBackButton());

		FunkinLua.registerFunction("setActivityTitle", function(text:String) {
			if (text == null)
				return FunkinLua.luaTrace('setActivityTitle: No text specified.');
			PsychJNI.setActivityTitle(text);
		});
		#end
	}

	public static function implementLocal(funk:FunkinLua) {
		funk.set('mobileC', Controls.instance.mobileC);
		funk.set('mobileControlsMode', getMobileControlsAsString());
	}

	public static function getMobileControlsAsString():String {
		switch (MobileData.mode) {
			case 0:
				return 'left';
			case 1:
				return 'right';
			case 2:
				return 'custom';
			case 3:
				return 'hitbox';
			default:
				return 'none';
		}
	}
}
#end
