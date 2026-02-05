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
      WindowOptions windowOptions = const WindowOptions(
        size: Size(900, 700),
        center: true,
        backgroundColor: Colors.white, // OPAQUE for visibility
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal, // STANDARD TITLE BAR
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
      _initLocalization();
      
      safeLog('SystemTray Init...');
      await _initSystemTray();
      
      safeLog('HotKeys Init...');
      _initHotkeys();
      
      safeLog('HotCorners Start...');
      HotCornerManager().start();
      
      setState(() {
        _statusMessage = "Ready";
      });
    } catch (e, s) {
      safeLog('APP INITIALIZATION FAILED: $e\n$s');
      setState(() {
        _statusMessage = "Error: $e";
      });
    }
  }

  void _initLocalization() {
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
          //_toggleSuspension(); // Simplified for debug
          safeLog('Hotkey pressed');
        },
      );
    } catch (e) {
      safeLog('Hotkey Error: $e');
    }
  }

  Future<void> _initSystemTray() async {
    String iconPath = 'assets/app_icon.ico';
    if (Platform.isWindows) {
      final String exePath = Platform.resolvedExecutable;
      final String exeDir = File(exePath).parent.path;
      iconPath = '$exeDir\\data\\flutter_assets\\assets\\app_icon.ico';
    }
    
    safeLog('Tray Icon Path: $iconPath (Exists: ${File(iconPath).existsSync()})');

    try {
      await _systemTray.initSystemTray(
        title: "uKotka HotCorners Debug",
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
  // Initialize Services
  await ConfigService().init();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // await windowManager.hide(); // DISABLED DEBUG: Force show on start
    await windowManager.show();
    await windowManager.focus();
  });

  // Start HotCorner Engine
  HotCornerManager().start();

  runApp(const UKotkaHotCornersApp());
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
  Timer? _suspendTimer;

  @override
  void initState() {
    super.initState();
    _initLocalization();
    _initSystemTray();
    _initHotkeys();
  }

  void _initLocalization() {
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
    // Simplified hotkey registration - matching version 0.2.3 positional constructor
    HotKey hotKey = HotKey(
      key: LogicalKeyboardKey.keyS,
      modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system,
    );

    hotKeyManager.register(
      hotKey,
      keyDownHandler: (hotKey) {
        _toggleSuspension();
      },
    );
  }

  void _toggleSuspension([Duration? duration]) {
    setState(() {
      ConfigService().setSuspended(!ConfigService().isSuspended);
      _suspendTimer?.cancel();
      
      if (ConfigService().isSuspended && duration != null) {
        _suspendTimer = Timer(duration, () {
          setState(() => ConfigService().setSuspended(false));
          _updateTray();
        });
      }
    });
    _updateTray();
  }

  Future<void> _updateTray() async {
    final statusText = ConfigService().isSuspended ? " (ZAWIESZONO)" : "";
    await _systemTray.setToolTip("uKotka HotCorners$statusText");
  }

  void _log(String message) {
    final file = File('${File(Platform.resolvedExecutable).parent.path}\\debug.log');
    file.writeAsStringSync('${DateTime.now()}: $message\n', mode: FileMode.append);
  }

  Future<void> _initSystemTray() async {
    String iconPath = 'assets/app_icon.ico';
    if (Platform.isWindows) {
      final String exePath = Platform.resolvedExecutable;
      final String exeDir = File(exePath).parent.path;
      iconPath = '$exeDir\\data\\flutter_assets\\assets\\app_icon.ico';
    }
    
    _log('Init System Tray. Icon Path: $iconPath');
    _log('Icon file exists: ${File(iconPath).existsSync()}');

    try {
      await _systemTray.initSystemTray(
        title: "uKotka HotCorners",
        iconPath: iconPath,
      );
      _log('System Tray initialized successfully');
    } catch (e) {
      _log('System Tray Error: $e');
    }

    // Force show window to ensure UI availability
    _log('Force showing window');
    windowManager.show();

    // Show settings on first launch or if specifically requested
    if (!ConfigService().hasConfig || ConfigService().launchAtStartup == false) {
       // Small delay to ensure window system is ready
       Future.delayed(const Duration(milliseconds: 500), () {
         windowManager.show();
       });
    }

    await _menu.buildFrom([
      MenuItemLabel(label: 'Ustawienia', onClicked: (menuItem) => windowManager.show()),
      MenuSeparator(),
      SubMenu(label: 'Zawieś działanie', children: [
        MenuItemLabel(label: 'Na 5 minut', onClicked: (menuItem) => _toggleSuspension(const Duration(minutes: 5))),
        MenuItemLabel(label: 'Na 30 minut', onClicked: (menuItem) => _toggleSuspension(const Duration(minutes: 30))),
        MenuItemLabel(label: 'Na 1 godzinę', onClicked: (menuItem) => _toggleSuspension(const Duration(hours: 1))),
        MenuItemLabel(label: 'Na stałe', onClicked: (menuItem) => _toggleSuspension()),
      ]),
      MenuItemLabel(label: 'Wznów działanie', onClicked: (menuItem) {
        setState(() => ConfigService().setSuspended(false));
        _updateTray();
      }),
      MenuSeparator(),
      MenuItemLabel(label: 'Wyjście', onClicked: (menuItem) => windowManager.close()),
    ]);

    await _systemTray.setContextMenu(_menu);
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      supportedLocales: _localization.supportedLocales,
      localizationsDelegates: _localization.localizationsDelegates,
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
}
