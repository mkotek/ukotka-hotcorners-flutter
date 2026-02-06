import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:system_tray/system_tray.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'logic/localization.dart';
import 'logic/config_service.dart';
import 'logic/hot_corner_manager.dart';
import 'screens/settings_screen.dart';

// GLOBAL LOGGER
void safeLog(String message) {
  try {
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    final logFile = File(p.join(exeDir, 'crash_debug.txt'));
    final timestamp = DateTime.now().toString().split('.').first; // Cleaner timestamp
    logFile.writeAsStringSync('[$timestamp] $message\n', mode: FileMode.append);
    debugPrint(message); // Also log to console
  } catch (e) {
    // If we can't log, we are doomed, but don't crash
  }
}

void main() async {
  runZonedGuarded(() async {
    safeLog('=== APP STARTING ===');
    
    try {
      WidgetsFlutterBinding.ensureInitialized();
      safeLog('WidgetsFlutterBinding initialized');

      await windowManager.ensureInitialized();
      safeLog('WindowManager initialized');

      // STANDARD WINDOW CONFIGURATION (Debug/Safe Mode)
      // Opaque, standard title bar to ensure visibility
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1000, 800),
        center: true,
        backgroundColor: Colors.white,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setPreventClose(true); // Prevent app exit on X click
        safeLog('Window shown and focused (Close prevented)');
      });

    } catch (e, s) {
      safeLog('INIT ERROR: $e\n$s');
    }

    runApp(const UKotkaHotCornersApp());
  }, (error, stack) {
    safeLog('UNCAUGHT ERROR: $error\n$stack');
  });
}

class UKotkaHotCornersApp extends StatefulWidget {
  const UKotkaHotCornersApp({super.key});

  @override
  State<UKotkaHotCornersApp> createState() => _UKotkaHotCornersAppState();
}

class _UKotkaHotCornersAppState extends State<UKotkaHotCornersApp> with WindowListener {
  final FlutterLocalization _localization = FlutterLocalization.instance;
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    safeLog('State initState called, WindowListener added');
    _initializeApp();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      safeLog('Window close intercepted - Hiding to tray');
      await windowManager.hide();
    }
  }

  Future<void> _initializeApp() async {
    try {
      safeLog('ConfigService Init...');
      await ConfigService().init();
      
      safeLog('Localization Init...');
      await _initLocalization();
      
      safeLog('HotCorners Start...');
      HotCornerManager().start();
      
      setState(() {
        _statusMessage = "Ready";
      });
      
      // Defer Tray Init until after UI is built and potentially window is shown
      // This is a race condition fix for HWND availability
      Future.delayed(const Duration(seconds: 1), () async {
         safeLog('Delayed SystemTray Init...');
         await _initSystemTray();
      });

    } catch (e, s) {
      safeLog('APP INITIALIZATION FAILED: $e\n$s');
    } catch (e, s) {
      safeLog('APP INITIALIZATION FAILED: $e\n$s');
      setState(() {
        _statusMessage = "Error: $e";
      });
    }
  }

  Future<void> _initLocalization() async {
    await _localization.ensureInitialized();
    _localization.init(
      mapLocales: [
        const MapLocale('en', AppLocale.EN),
        const MapLocale('pl', AppLocale.PL),
      ],
      initLanguageCode: 'pl',
    );
    _localization.onTranslatedLanguage = (_) => setState(() {});
  }

  void _initHotkeys() {
    try {
      HotKey hotKey = HotKey(
        key: LogicalKeyboardKey.keyS,
        modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
        scope: HotKeyScope.system,
      );

      hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          safeLog('Hotkey pressed');
          // Implement logic here if needed
        },
      );
    } catch (e) {
      safeLog('Hotkey Error: $e');
    }
  }

  Future<void> _initSystemTray() async {
    try {
      safeLog('Starting _initSystemTray...');
      
      // Use join for robust path handling
      final String tempPath = p.join(Directory.systemTemp.path, 'ukotka_tray_icon.ico');
      final File tempIcon = File(tempPath);
      
      safeLog('Loading asset app_icon.ico...');
      final ByteData data = await rootBundle.load('assets/app_icon.ico');
      final List<int> bytes = data.buffer.asUint8List();
      
      safeLog('Writing icon to temp: $tempPath');
      await tempIcon.writeAsBytes(bytes, flush: true);
      
      if (!await tempIcon.exists()) {
        throw Exception("Failed to create temp icon file");
      }

      safeLog('Calling _systemTray.initSystemTray...');
      await _systemTray.initSystemTray(
        title: "uKotka HotCorners",
        iconPath: tempPath,
      );
      
      safeLog('Building tray menu...');
      await _menu.buildFrom([
        MenuItemLabel(label: 'Pokaż', onClicked: (menuItem) {
          safeLog('Tray Menu: Show clicked');
          windowManager.show();
        }),
        MenuItemLabel(label: 'Zamknij', onClicked: (menuItem) {
          safeLog('Tray Menu: Close clicked - Exiting app');
          windowManager.destroy(); // Force exit
        }),
      ]);
      await _systemTray.setContextMenu(_menu);
      
      _systemTray.registerSystemTrayEventHandler((eventName) {
        safeLog('SystemTray Event: $eventName');
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
      
      safeLog('SystemTray successfully initialized');
    } catch (e, s) {
      safeLog('Tray Init Failed: $e\n$s');
    }
  }

  @override
  Widget build(BuildContext context) {
    // If ready, show the actual app!
    if (_statusMessage == "Ready") {
      return MaterialApp(
        supportedLocales: _localization.supportedLocales,
        localizationsDelegates: [
          ..._localization.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        title: 'uKotka HotCorners',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F0F0F),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00C2FF),
            brightness: Brightness.dark,
            primary: const Color(0xFF00C2FF),
          ),
          useMaterial3: true,
        ),
        home: const SettingsScreen(),
      );
    }
    
    // Otherwise show the Debug/Loading Safe Screen
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text("uKotka Loader")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.build_circle, size: 64, color: Colors.blue),
              const SizedBox(height: 20),
              Text("Status: $_statusMessage", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              if (_statusMessage.startsWith("Error"))
                ElevatedButton(
                  onPressed: () => windowManager.close(),
                  child: const Text("Zamknij"),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
