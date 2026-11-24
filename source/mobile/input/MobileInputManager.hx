package mobile.input;

import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import haxe.ds.Map;
import mobile.objects.TouchButton;

/**
 * A TouchButton group with functions for input handling.
 * @author Karim Akra
 */
class MobileInputManager extends FlxTypedSpriteGroup<TouchButton>
{
	/**
         * A map to keep track of all the buttons using its ID.
         */
	public var trackedButtons:Map<MobileInputID, TouchButton> = new Map<MobileInputID, TouchButton>();

	public function new()
	{
		super();
		updateTrackedButtons();
	}

	/**
         * Check to see if the button was pressed.
         *
         * @param       button  A button ID
         * @return      Whether at least one of the buttons passed was pressed.
         */
	public inline function buttonPressed(button:MobileInputID):Bool
	{
		return anyPressed([button]);
	}

	/**
         * Check to see if the button was just pressed.
         */
	public inline function buttonJustPressed(button:MobileInputID):Bool
	{
		return anyJustPressed([button]);
	}

	/**
         * Check to see if the button was just released.
         */
	public inline function buttonJustReleased(button:MobileInputID):Bool
	{
		return anyJustReleased([button]);
	}

	/**
         * Check to see if at least one button from an array of buttons is pressed.
         */
	public inline function anyPressed(buttonsArray:Array<MobileInputID>):Bool
	{
		return checkButtonArrayState(buttonsArray, PRESSED);
	}

	/**
         * Check to see if at least one button from an array of buttons was just pressed.
         */
	public inline function anyJustPressed(buttonsArray:Array<MobileInputID>):Bool
	{
		return checkButtonArrayState(buttonsArray, JUST_PRESSED);
	}

	/**
         * Check to see if at least one button from an array of buttons was just released.
         */
	public inline function anyJustReleased(buttonsArray:Array<MobileInputID>):Bool
	{
		return checkButtonArrayState(buttonsArray, JUST_RELEASED);
	}

	/**
         * Check the status of a single button.
         */
	public function checkStatus(button:MobileInputID, state:ButtonsStates = JUST_PRESSED):Bool
	{
		switch (button)
		{
			case MobileInputID.ANY:
				for (trackedButton in trackedButtons.keys())
				{
					if (checkStatusUnsafe(trackedButton, state))
						return true;
				}
			case MobileInputID.NONE:
				return false;

			default:
				if (trackedButtons.exists(button))
					return checkStatusUnsafe(button, state);
		}
		return false;
	}

	function checkButtonArrayState(buttons:Array<MobileInputID>, state:ButtonsStates = JUST_PRESSED):Bool
	{
		if (buttons == null)
			return false;

		for (button in buttons)
			if (checkStatus(button, state))
				return true;

		return false;
	}

	function checkStatusUnsafe(button:MobileInputID, state:ButtonsStates = JUST_PRESSED):Bool
	{
		return switch (state)
		{
			case JUST_RELEASED: trackedButtons.get(button).justReleased;
			case PRESSED: trackedButtons.get(button).pressed;
			case JUST_PRESSED: trackedButtons.get(button).justPressed;
		}
	}

	public function updateTrackedButtons()
	{
		trackedButtons.clear();
		forEachExists(function(button:TouchButton)
		{
			if (button.IDs != null)
			{
				for (id in button.IDs)
				{
					if (!trackedButtons.exists(id))
						trackedButtons.set(id, button);
				}
			}
		});
	}
}

enum ButtonsStates
{
	PRESSED;
	JUST_PRESSED;
	JUST_RELEASED;
}
