package org.haxe.extension;

import android.os.Build;
import android.os.Bundle;

/**
 * Turns the Android back button and the back gesture into a game input instead of
 * letting the system finish the activity.
 *
 * The press is queued here and polled through {@link #consume()} once per frame from
 * the Haxe side, where `mobile.backend.SystemBack` decides which state receives it.
 */
public class PsychBackButton extends Extension {

	private static volatile boolean pending = false;

	// A single press can reach us twice (key down plus key up, or the legacy onBackPressed
	// after the OnBackInvokedCallback). Two reports in a row open and instantly close the
	// pause menu, so a report that follows another one this quickly is the same press.
	private static final long DUPLICATE_WINDOW_MS = 250L;
	private static volatile long lastReport = 0L;

	@Override
	public void onCreate (Bundle savedInstanceState) {

		super.onCreate (savedInstanceState);

		// Android 16 (API 36) delivers back through OnBackInvokedCallback, so both
		// entry points are needed to catch every device and navigation mode
		if (Build.VERSION.SDK_INT >= 33) {

			PsychBackInvoked.register ();
		}
	}

	public boolean onBackPressed () {

		notifyBack ();

		// lime only calls super.onBackPressed (which finishes the activity) when every extension returns true
		return false;
	}

	static void notifyBack () {

		pending = true;
	}

	/**
	 * Returns true once per back press and drops the queued event.
	 */
	public static boolean consume () {

		if (!pending) {

			return false;
		}

		pending = false;

		final long now = android.os.SystemClock.uptimeMillis ();

		if (now - lastReport < DUPLICATE_WINDOW_MS) {

			return false;
		}

		lastReport = now;
		return true;
	}

	/**
	 * Drops a press that arrived while the game was not updating (paused or backgrounded).
	 */
	public static void clear () {

		pending = false;
		lastReport = 0L;
	}
}
