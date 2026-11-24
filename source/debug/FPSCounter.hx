package debug;

import flixel.FlxG;
import haxe.Timer;
import lime.system.System as LimeSystem;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;

#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:cppFileCode('#include <sys/utsname.h>')
#end
#end

/**
	The FPS class provides an easy-to-use monitor to display
	the current frame rate of an OpenFL project
**/
class FPSCounter extends TextField
{
	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;

	public var os:String = '';

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		final arch:String = #if cpp getArch() #else 'Unknown' #end;
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = '\nOS: ${LimeSystem.platformName}' + (arch != 'Unknown' ? ' $arch' : '');
		else
			os = '\nOS: ${LimeSystem.platformName}' + (arch != 'Unknown' ? ' $arch' : '') + ' - ${LimeSystem.platformVersion}';

		positionFPS(x, y);

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		shader = new debug.ScriptTraceDisplay.DebugTextShader();
		defaultTextFormat = new TextFormat(Paths.font('vcr.ttf'), 15, color);
		autoSize = LEFT;
		multiline = true;
		text = "FPS: ";

		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
	}

	public dynamic function updateText():Void { // so people can override it in hscript
		text = 'FPS: ${currentFPS}'
		#if cpp + '\nMemory: ${flixel.util.FlxStringUtil.formatBytes(memoryMegas)}' #end
		+ os;

		textColor = 0xFFFFFFFF;
		if (currentFPS < FlxG.drawFramerate * 0.5)
			textColor = 0xFFFF0000;
	}

	var deltaTimeout:Float = 0.0;

	// Event Handlers
	private override function __enterFrame(deltaTime:Float):Void
	{
		if (ClientPrefs.data.fpsRework)
		{
			// Flixel keeps reseting this to 60 on focus gained
			if (FlxG.stage.window.frameRate != ClientPrefs.data.framerate && FlxG.stage.window.frameRate != FlxG.game.focusLostFramerate)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;

			final currentTime:Int = Lib.getTimer();
			framesCount++;

			if (currentTime >= updateTime)
			{
				final elapsed:Int = currentTime - prevTime;
				currentFPS = Math.ceil((framesCount * 1000) / elapsed);
				framesCount = 0;
				prevTime = currentTime;
				updateTime = currentTime + 500;
			}

			// Set update and draw framerate to the measured FPS every 1.5 seconds to prevent the "slow motion" issue
			if ((FlxG.updateFramerate >= currentFPS + 5 || FlxG.updateFramerate <= currentFPS - 5)
				&& Timer.stamp() - lastFramerateUpdateTime >= 1.5
				&& currentFPS >= 30)
			{
				FlxG.updateFramerate = FlxG.drawFramerate = currentFPS;
				lastFramerateUpdateTime = Timer.stamp();
			}
		}
		else
		{
			final now:Float = Timer.stamp() * 1000;
			times.push(now);
			while (times[0] < now - 1000) times.shift();
			// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
			if (deltaTimeout < 50)
			{
				deltaTimeout += deltaTime;
				return;
			}

			currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
			deltaTimeout = 0.0;
		}

		updateText();
	}

	inline function get_memoryMegas():#if cpp Float #else Int #end
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}

	/**
		Puts the counter inside the game view and keeps it on screen on every resolution
		and display density. `viewScale` is the ratio between the game view and the
		logical game size (`FlxG.width`), which is greater than 1 on high density Android screens.
	**/
	public function positionFPS(X:Float, Y:Float, ?viewScale:Float = 1):Void
	{
		final scale:Float = #if android (viewScale > 1 ? viewScale : 1) #else (viewScale < 1 ? viewScale : 1) #end;
		scaleX = scaleY = scale;

		var posX:Float = (FlxG.game != null ? FlxG.game.x : 0) + X;
		var posY:Float = (FlxG.game != null ? FlxG.game.y : 0) + Y;

		final stageWidth:Float = Lib.current.stage.stageWidth;
		final stageHeight:Float = Lib.current.stage.stageHeight;
		final textWidth:Float = width * scale;
		final textHeight:Float = height * scale;

		if (posX + textWidth > stageWidth)
			posX = Math.max(0, stageWidth - textWidth);
		if (posY + textHeight > stageHeight)
			posY = Math.max(0, stageHeight - textHeight);

		this.x = posX;
		this.y = posY;
	}

	#if cpp
	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
	#elseif (ios || mac)
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
		return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#else
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}
