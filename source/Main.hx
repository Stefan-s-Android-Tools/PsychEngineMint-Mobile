package;

#if android
import extension.androidtools.content.Context;
#end

import debug.FPSCounter;
import debug.ScriptTraceDisplay;

import flixel.graphics.FlxGraphic;
import flixel.FlxGame;
import flixel.FlxState;
import haxe.io.Path;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.display.StageScaleMode;
import lime.app.Application;
import states.TitleState;

#if HSCRIPT_ALLOWED
import scripting.hscript.FunkinHscript;
#end
#if GLOBAL_SCRIPTS
import scripting.GlobalScripts;
#end

#if (linux || mac)
import lime.graphics.Image;
#end

#if desktop
import backend.ALSoftConfig; // Just to make sure DCE doesn't remove this, since it's not directly referenced anywhere else.
#end

//crash handler stuff
#if CRASH_HANDLER
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
#end

import backend.Highscore;
import backend.ScriptedState;
import mobile.backend.MobileScaleMode;

// NATIVE API STUFF, YOU CAN IGNORE THIS AND SCROLL //
#if (linux && !debug)
@:cppInclude('./external/gamemode_client.h')
@:cppFileCode('#define GAMEMODE_AUTO')
#end

// // // // // // // // //
class Main extends Sprite
{
	public static final game = {
		width: 1280, // WINDOW width
		height: 720, // WINDOW height
		initialState: TitleState, // initial game state
		framerate: 60, // default framerate
		skipSplash: true, // if the default flixel splash screen should be skipped
		startFullscreen: false // if the game should start at fullscreen mode
	};
	public static var appName(default, null):String;
	
	public static var fpsVar:FPSCounter;
	public static var traces:ScriptTraceDisplay;
	
	// You can pretty much ignore everything from here on - your code should go in your states.
	
	public function new()
	{
		super();
		
		#if CRASH_HANDLER
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end
		
		appName = (FlxG.stage.application.meta.get('file') ?? 'PsychEngineMint');
		
		#if (cpp && windows)
		backend.Native.fixScaling();
		#end
		
		// Credits to MAJigsaw77 (he's the og author for this code)
		#if android
		var storageDir:String = mobile.backend.StorageUtil.getStorageDirectory();
		final fallbackDir:String = Path.addTrailingSlash(Context.getExternalFilesDir());

		mobile.backend.StorageUtil.createDirectories(storageDir);
		if (!mobile.backend.StorageUtil.isWritable(storageDir))
		{
			// ask for shared storage access before giving up on the external folder
			mobile.backend.StorageUtil.requestPermissions();
			trace('Cannot write to "$storageDir", falling back to "$fallbackDir"');
			storageDir = fallbackDir;
		}
		else if (!FileSystem.exists(storageDir + 'saves') && FileSystem.exists(fallbackDir + 'saves'))
		{
			// first launch after switching to external storage: bring the old data along
			mobile.backend.StorageUtil.copyContents(fallbackDir, storageDir, ['mods', 'saves', 'crash', 'logs']);
		}

		Sys.setCwd(storageDir);
		mobile.backend.StorageUtil.setupGameDirectory(Path.addTrailingSlash(storageDir));
		#elseif ios
		Sys.setCwd(lime.system.System.applicationStorageDirectory);
		#end
		
		#if hxvlc
		hxvlc.util.Handle.init(#if (hxvlc >= "1.8.0")  ['--no-lua'] #end);
		#end
		
		#if LUA_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();
		
		FlxG.signals.postGameReset.add(function() {
			#if (!html5 && !switch) FlxG.autoPause = ClientPrefs.data.autoPause; #end
			FlxG.fixedTimestep = false;
		});
		
		FlxG.save.bind('funkin', CoolUtil.getSavePath());
		Controls.instance = new Controls();
		Language.reloadPhrases();
		Difficulty.resetList();
		
		#if GLOBAL_SCRIPTS GlobalScripts.init(); #end
		#if HSCRIPT_ALLOWED FunkinHscript.init(); #end
		#if LUA_ALLOWED Lua.set_callbacks_function(cpp.Callable.fromStaticFunction(scripting.lua.CallbackHandler.call)); #end
		
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end
		addChild(new #if UNHOLYWANDERER04 UnholyGame #else FlxGame #end(game.width, game.height, game.initialState, game.framerate, game.framerate, game.skipSplash, game.startFullscreen));
		
		ClientPrefs.loadPrefs();
		Highscore.load();
		
		substates.OutdatedSubState.updateVersion = CoolUtil.checkForUpdates();
		
		traces = new ScriptTraceDisplay();
		addChild(traces);
		
		fpsVar = new FPSCounter(12, 4, 0xffffff);
		addChild(fpsVar);
		Lib.current.stage.align = "tl";
		Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
		if(fpsVar != null) {
			fpsVar.visible = ClientPrefs.data.showFPS;
		}
		
		#if (linux || mac) // fix the app icon not showing up on the Linux Panel / Mac Dock
		var icon = Image.fromFile("icon.png");
		Lib.current.stage.window.setIcon(icon);
		#end
		
		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end
		
		FlxG.game.focusLostFramerate = 60;
		FlxG.keys.preventDefaultKeys = [TAB];
		
		#if DISCORD_ALLOWED
		DiscordClient.prepare();
		#end
		
		#if android FlxG.android.preventDefaultKeys = [flixel.input.android.FlxAndroidKey.BACK]; #end

		#if mobile
		lime.system.System.allowScreenTimeout = ClientPrefs.data.screensaver;
		FlxG.scaleMode = new MobileScaleMode();
		#end

		updateFPSPosition();

		#if android
		// the system back button/gesture is queued by the Java extension and has to be picked
		// up once per frame, before any state reads `Controls`
		FlxG.signals.preUpdate.add(mobile.backend.SystemBack.poll);

		// the GL context only exists once the window renders, so the report waits for it
		Lib.current.stage.window.onRender.add(logGraphicsBackend);
		#end

		// shader coords fix
		FlxG.signals.gameResized.add((w:Int, h:Int) -> {
			updateFPSPosition();
		     if (FlxG.cameras != null) {
			   for (cam in FlxG.cameras.list) {
				if (cam != null && cam.filters != null)
					resetSpriteCache(cam.flashSprite);
			   }
			}

			if (FlxG.game != null)
			resetSpriteCache(FlxG.game);
		});
	}
	
	/**
	 * Scales and clamps the FPS counter to the game view. Android renders the game in
	 * physical pixels, so the counter has to follow the current scale factor to stay
	 * readable and inside the screen on every resolution and density.
	 */
	public static function updateFPSPosition():Void
	{
		if (fpsVar == null) return;

		final scale:Float = (FlxG.scaleMode != null ? FlxG.scaleMode.scale.x : 1);
		fpsVar.positionFPS(12, 4, scale);
	}

	#if android
	static var graphicsLogged:Bool = false;

	/**
	 * Android renders through OpenGL ES: lime compiles its GL backend against `GLES2/gl2.h` and
	 * links `libGLESv2`/`libEGL`, so `hardware="true"` always yields an ES context (2.0, or 3.x on
	 * newer devices) and OpenFL compiles the shaders as GLSL ES. There is no Project.xml switch for
	 * it, so log what the device actually handed us, together with the texture size limit that
	 * oversized mod spritemaps run into.
	 */
	static function logGraphicsBackend(?context:lime.graphics.RenderContext):Void
	{
		Lib.current.stage.window.onRender.remove(logGraphicsBackend);
		if (graphicsLogged) return;
		graphicsLogged = true;

		try
		{
			final version:String = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.VERSION);
			final renderer:String = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.RENDERER);
			final maxTexture:Int = lime.graphics.opengl.GL.getParameter(lime.graphics.opengl.GL.MAX_TEXTURE_SIZE);

			trace('GRAPHICS: $version | $renderer | max texture size: ${maxTexture}px');
			if (version == null || version.indexOf('OpenGL ES') < 0)
				trace('GRAPHICS: expected an OpenGL ES context on Android but got "$version"; rendering may misbehave.');

			backend.Paths.maxTextureSize = maxTexture;
		}
		catch (e:Dynamic) trace('GRAPHICS: could not read the GL context. ($e)');
	}
	#end


	static function resetSpriteCache(sprite:Sprite):Void {
		@:privateAccess {
		        sprite.__cacheBitmap = null;
			sprite.__cacheBitmapData = null;
		}
	}
	
	// Code was entirely made by sqirra-rng for their fnf engine named "Izzy Engine", big props to them!!!
	// very cool person for real they don't get enough credit for their work
	#if CRASH_HANDLER
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var gh:String = 'https://github.com/inky03/FNF-PsychEngineMint'; // change this link to your actual repository if you're modding !
		var dateNow:String = Date.now().toString().replace(' ', '_').replace(':', "'"); // yayyyy
		
		var errMsg:String = 'UNCAUGHT EXCEPTION: ${e.error}\n\nSTACK TRACEBACK:';
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		
		function stackItemToString(stackItem:haxe.CallStack.StackItem) {
			return switch (stackItem) {
				case FilePos(s, file, line, col):
					'$file:${col == null ? '' : ':$col'}$line (${stackItemToString(s)})';
				case CFunction:
					'Function from C';
				case Module(m):
					'Module $m';
				case Method(cls, method):
					'Method ${cls ?? '<unknown>'}.$method';
				case LocalFunction(n):
					'Local function #$n';
			}
		}
		
		for (stackItem in callStack)
			errMsg += ('\n' + stackItemToString(stackItem));
		
		var errText:String = '$appName ${states.MainMenuState.modVersion}\n\n$errMsg\n\n$gh\n';
		
		#if sys
		var path:String = './crash/${appName}_$dateNow.txt';
		errMsg += '\n\nA crash dump has been saved in ${Path.normalize(path)}';
		#end
		
		#if officialBuild
		errMsg += '\n\nIf you believe this error was caused by the engine, report this issue at $gh';
		#end
		errMsg += '\n\n> Crash Handler written by sqirra-rng';
		
		#if sys
		if (!FileSystem.exists("./crash/"))
			FileSystem.createDirectory("./crash/");
		
		File.saveContent(path, errText);
		Sys.println(errText);
		#end
		
		Application.current.window.alert(errMsg, 'Oops...');
		#if DISCORD_ALLOWED
		DiscordClient.shutdown();
		#end
		#if sys
		Sys.exit(1);
		#end
	}
	#end
}

#if UNHOLYWANDERER04
class UnholyGame extends flixel.FlxGame {
	public var frameCounter:Int = 0;
	
	override function onEnterFrame(_) {
		super.onEnterFrame(_);
		frameCounter ++;
	}
}
#end
