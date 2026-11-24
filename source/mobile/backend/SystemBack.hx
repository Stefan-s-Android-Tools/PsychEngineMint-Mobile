package mobile.backend;

#if android
import lime.system.JNI;
#end

/**
 * Routes the Android back button and back gesture into the engine input instead of letting
 * the system close the activity.
 *
 * `Main` polls the native queue once per frame and `Controls` exposes the queued press as
 * the `pause`/`back` action, but only for the state that owns the mobile input, so one press
 * can never be handled by two menus at the same time.
 */
class SystemBack
{
#if android
	static inline var EXTENSION_CLASS:String = 'org/haxe/extension/PsychBackButton';

	static var consumeFunction:Dynamic;
	static var consumeFunctionResolved:Bool = false;
	static var pending:Bool = false;
	// Who owned the mobile input when the press arrived. Captured at poll time because a
	// substate opened by the press reads `back` in the same frame; if the owner were resolved
	// when the action is read, the pause menu would count itself as the owner and resume.
	static var owner:MusicBeatSubstate = null;
	static var ownerCaptured:Bool = false;

	/**
	 * Called once per frame from `Main`, before any state updates.
	 */
	public static function poll():Void
	{
		pending = false;
		owner = null;
		ownerCaptured = false;

		if (!consumeFunctionResolved)
		{
			consumeFunctionResolved = true;
			consumeFunction = JNI.createStaticMethod(EXTENSION_CLASS, 'consume', '()Z');
		}

		if (consumeFunction != null && consumeFunction() == true)
		{
			pending = true;
			owner = MusicBeatSubstate.getInputTarget();
			ownerCaptured = true;
		}

		// while a text field is being edited, back only has to close the on-screen keyboard
		if (pending && backend.ui.PsychUIInputText.focusOn != null)
		{
			backend.ui.PsychUIInputText.focusOn = null;
			pending = false;
		}
	}
#end

	public static function requested():Bool
	{
#if android
		return pending;
#else
		return false;
#end
	}

	/**
	 * Reports the queued system back press as `key` while `instance` owns the input.
	 * A `null` instance means no substate is listening, so the running state gets it.
	 */
	public static function justPressed(key:String, ?instance:MusicBeatSubstate):Bool
	{
#if android
		return pending && isBackAction(key) && ownsInput(instance);
#else
		return false;
#end
	}

	public static function pressed(key:String, ?instance:MusicBeatSubstate):Bool
	{
		return justPressed(key, instance);
	}

#if android
	static inline function isBackAction(key:String):Bool
		return key == 'back' || key == 'pause';

	static function ownsInput(?instance:MusicBeatSubstate):Bool
	{
		if (!ownerCaptured)
			return false;

		// `null` on both sides means the running state owned the input when the press arrived
		return instance == owner;
	}
#end
}
