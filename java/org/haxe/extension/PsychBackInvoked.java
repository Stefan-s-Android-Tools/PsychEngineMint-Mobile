package org.haxe.extension;

import android.window.OnBackInvokedDispatcher;

/**
 * Kept in its own class so devices below API 33 never load the OnBackInvoked API.
 */
final class PsychBackInvoked {

	private PsychBackInvoked () {}

	static void register () {

		Extension.mainActivity.getOnBackInvokedDispatcher ().registerOnBackInvokedCallback (
			OnBackInvokedDispatcher.PRIORITY_DEFAULT,
			new OnBackInvokedDispatcher.OnBackInvokedCallback () {

				@Override
				public void onBackInvoked () {

					PsychBackButton.notifyBack ();
				}
			}
		);
	}
}
