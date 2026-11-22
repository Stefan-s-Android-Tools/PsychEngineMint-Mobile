#!/bin/sh
# SETUP + BUILD FOR ANDROID (Linux / Mac)
# REQUIRES: Haxe 4.3.x, JDK 21, Android SDK (platform android-36, build-tools 36.0.0)
# and NDK r29 (29.0.14206865).
#
# Usage (run it from the folder where this script lives, e.g. setup/):
#   sh setup-android.sh              -> installs dependencies and builds a release APK
#   sh setup-android.sh debug        -> installs dependencies and builds a debug APK
#   sh setup-android.sh setup-only   -> only installs dependencies
#
# Optional env vars to configure Lime automatically (otherwise run
# "haxelib run lime setup android" once):
#   ANDROID_SDK_ROOT, ANDROID_NDK_ROOT, JAVA_HOME

set -e

MODE="${1:-release}"

cd "$(dirname "$0")/.."

echo "Making the main haxelib and setting up the folder at the same time.."
mkdir -p ~/haxelib && haxelib setup ~/haxelib

echo "Installing dependencies..."
echo "This might take a few moments depending on your internet speed."
haxelib install hxcpp
haxelib install lime
haxelib install openfl
haxelib install flixel 6.1.2
haxelib install flixel-addons
haxelib install flixel-tools
haxelib install tjson
haxelib install hxvlc --skip-dependencies
haxelib git hscript-insanity https://github.com/inky03/hscript-insanity.git 26d72f5f83dc705587771597da257caa5aa6e1c3
# FIX: flixel-animate (package "animate") lives in MaybeMaru's repo.
# Dot-Stuff/flxanimate is the old library (package "flxanimate") and breaks "import animate.FlxAnimateFrames".
haxelib git flixel-animate https://github.com/MaybeMaru/flixel-animate.git
haxelib git linc_luajit https://github.com/superpowers04/linc_luajit.git
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis.git 1966f8fbbbc509ed90d4b520f3c49c084fc92fd6
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git
echo "Dependencies installed!"

if [ "$MODE" = "setup-only" ]; then
	echo "Done. Run 'haxelib run lime setup android' once if Lime is not configured yet."
	exit 0
fi

# FIX: GitHub runners predefine ANDROID_NDK_ROOT (r27). If the requested NDK is installed, force it.
if [ -n "$ANDROID_NDK_VERSION" ]; then
	SDK_DIR="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
	if [ -n "$SDK_DIR" ] && [ -d "$SDK_DIR/ndk/$ANDROID_NDK_VERSION" ]; then
		export ANDROID_NDK_ROOT="$SDK_DIR/ndk/$ANDROID_NDK_VERSION"
		echo "Using NDK $ANDROID_NDK_VERSION at $ANDROID_NDK_ROOT"
	fi
fi

# Configure Lime from env vars if they are set
if [ -n "$ANDROID_SDK_ROOT" ] && [ -n "$ANDROID_NDK_ROOT" ] && [ -n "$JAVA_HOME" ]; then
	echo "Configuring Lime for Android from environment variables..."
	haxelib run lime config ANDROID_SDK "$ANDROID_SDK_ROOT"
	haxelib run lime config ANDROID_NDK_ROOT "$ANDROID_NDK_ROOT"
	haxelib run lime config JAVA_HOME "$JAVA_HOME"
	haxelib run lime config ANDROID_SETUP true
elif [ ! -f ~/.lime/config.xml ]; then
	echo "ERROR: Lime is not configured for Android."
	echo "Either set ANDROID_SDK_ROOT, ANDROID_NDK_ROOT and JAVA_HOME and run this again,"
	echo "or run 'haxelib run lime setup android' once."
	exit 1
fi

# Placeholder keystore (same credentials as the <certificate> tag in the project file)
if [ ! -f key.keystore ]; then
	echo "key.keystore not found, generating a placeholder one..."
	keytool -genkeypair -noprompt \
		-keystore key.keystore \
		-storetype JKS \
		-storepass KEYSTORE_PASSWORD \
		-alias KEYSTORE_ALIAS \
		-keypass KEYSTORE_ALIAS_PASSWORD \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-dname "CN=PsychEngineMint, OU=None, O=None, L=None, ST=None, C=US"
fi

# The project file may be named Project.xml or project.xml (Linux is case-sensitive)
if [ -f Project.xml ]; then
	PROJECT=Project.xml
else
	PROJECT=project.xml
fi

echo "Building Android ($MODE) with $PROJECT..."
if [ "$MODE" = "debug" ]; then
	haxelib run lime build "$PROJECT" android -debug
else
	haxelib run lime build "$PROJECT" android -release
fi

APK=$(find export -name "*.apk" | head -n 1)
if [ -z "$APK" ]; then
	echo "Build finished but no APK was found under export/"
	exit 1
fi
echo "Build finished! APK: $APK"
