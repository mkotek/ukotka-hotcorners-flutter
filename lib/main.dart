import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:system_tray/system_tray.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:async';
import 'dart:io';

import 'logic/localization.dart';
import 'logic/config_service.dart';
import 'logic/hot_corner_manager.dart';
import 'screens/settings_screen.dart';

// GLOBAL LOGGER
void safeLog(String message) {
  try {
    final file = File('${File(Platform.resolvedExecutable).parent.path}\\crash_debug.txt');
    file.writeAsStringSync('${DateTime.now()}: $message\n', mode: FileMode.append);
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
        size: Size(900, 700),
        center: true,
        backgroundColor: Colors.white,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        safeLog('Window shown and focused');
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

class _UKotkaHotCornersAppState extends State<UKotkaHotCornersApp> {
  final FlutterLocalization _localization = FlutterLocalization.instance;
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    safeLog('State initState called');
    _initializeApp();
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
    // On Windows, 'app_icon' typically refers to the resource ID if not a path
    // We try to load from the executable resources first
    String iconPath = 'app_icon'; 
    
    safeLog('Attempting initSystemTray with resource name: $iconPath');

    try {
      await _systemTray.initSystemTray(
        title: "uKotka HotCorners",
        iconPath: iconPath,
      );
      
      await _menu.buildFrom([
        MenuItemLabel(label: 'Pokaż', onClicked: (menuItem) => windowManager.show()),
        MenuItemLabel(label: 'Zamknij', onClicked: (menuItem) => windowManager.close()),
      ]);
      await _systemTray.setContextMenu(_menu);
      
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          windowManager.show();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });
    } catch (e) {
      safeLog('Tray Init Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    safeLog('Building UI');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("uKotka Debug Mode")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bug_report, size: 64, color: Colors.orange),
              const SizedBox(height: 20),
              Text("Status: $_statusMessage"),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => windowManager.close(),
                child: const Text("Zamknij (Force Exit)"),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text("Check crash_debug.txt for logs"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
