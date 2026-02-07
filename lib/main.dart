import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:tray_manager/tray_manager.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showCornerFlash(Offset globalOffset) async {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) {
     safeLog('Overlay not available via navigatorKey.currentState?.overlay');
     return;
  }
  
  final Rect windowBounds = await windowManager.getBounds();
  final double localX = globalOffset.dx - windowBounds.left;
  final double localY = globalOffset.dy - windowBounds.top;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: localX - 60,
      top: localY - 60,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 0.0),
          duration: const Duration(milliseconds: 600),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.yellow.withOpacity(0.35),
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(color: Colors.yellow.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)
                  ],
                ),
              ),
            );
          },
          onEnd: () => entry.remove(),
        ),
      ),
    ),
  );
  overlay.insert(entry);
}

void showCornerPreview(int cornerIndex, double size, Offset globalCornerOffset) async {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) return;

  final Rect windowBounds = await windowManager.getBounds();
  final double localX = globalCornerOffset.dx - windowBounds.left;
  final double localY = globalCornerOffset.dy - windowBounds.top;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: cornerIndex == 1 || cornerIndex == 3 ? localX - size : localX,
      top: cornerIndex == 2 || cornerIndex == 3 ? localY - size : localY,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.yellow.withOpacity(0.3),
            border: Border.all(color: Colors.yellow, width: 2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Center(
            child: Icon(Icons.ads_click, color: Colors.black87, size: 20),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 800), () => entry.remove());
}

void main(List<String> args) async {
  runZonedGuarded(() async {
    safeLog('=== APP STARTING (Args: $args) ===');
    
    try {
      WidgetsFlutterBinding.ensureInitialized();
      safeLog('WidgetsFlutterBinding initialized');

      await windowManager.ensureInitialized();
      safeLog('WindowManager initialized');

      // STANDARD WINDOW CONFIGURATION (Debug/Safe Mode)
      // Opaque, standard title bar to ensure visibility
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1150, 900), // Larger for tabbed UI
        center: true,
        backgroundColor: Colors.transparent, // Allow transparency for overlay later
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'uKotka Hot Corners',
      );

      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setPreventClose(true); // Prevent app exit on X click
        
        // Handle CLI arguments
        if (args.contains('--suspend')) {
          await ConfigService().init();
          ConfigService().isSuspended = true;
          safeLog('CLI: Suspended via argument');
          await windowManager.hide();
          await windowManager.setSkipTaskbar(true);
        } else if (args.contains('--settings')) {
          await windowManager.show();
          await windowManager.focus();
        } else {
          // Default behavior
          await windowManager.show();
          await windowManager.focus();
        }
        
        safeLog('Window logic completed (Args handled)');
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

class _UKotkaHotCornersAppState extends State<UKotkaHotCornersApp> with WindowListener, TrayListener {
  final FlutterLocalization _localization = FlutterLocalization.instance;
  String _statusMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    safeLog('State initState called, Window/Tray listeners added');
    _initializeApp();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMinimize() async {
    safeLog('Window minimized - Hiding to tray');
    await windowManager.hide();
  }

  @override
  void onWindowClose() async {
    final config = ConfigService();
    if (config.dontAskExit) {
      if (config.minimizeOnClose) {
        safeLog('Auto-hiding to tray (dontAskExit: true)');
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } else {
        safeLog('Auto-destroying (dontAskExit: true)');
        await windowManager.destroy();
      }
      return;
    }

    _showExitDialog();
  }

  void _showExitDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    bool dontAskAgain = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Zamknij u Kotka Hot Corners"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Czy chcesz całkowicie zamknąć aplikację, czy tylko schować ją do paska zadań (tray)?"),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text("Nie pytaj ponownie"),
                    value: dontAskAgain,
                    activeColor: const Color(0xFF00C2FF),
                    onChanged: (val) => setState(() => dontAskAgain = val!),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final config = ConfigService();
                    config.dontAskExit = dontAskAgain;
                    config.minimizeOnClose = true;
                    await config.save();
                    Navigator.pop(context);
                    await windowManager.hide();
                    await windowManager.setSkipTaskbar(true);
                    safeLog('User chose: Minimize to tray');
                  },
                  child: const Text("Schowaj do traya"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final config = ConfigService();
                    config.dontAskExit = dontAskAgain;
                    config.minimizeOnClose = false;
                    await config.save();
                    Navigator.pop(context);
                    await windowManager.destroy();
                    safeLog('User chose: Exit app');
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.8)),
                  child: const Text("Zamknij aplikację"),
                ),
              ],
            );
          },
        );
      },
    );
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
      final hotkeyStr = ConfigService().suspendHotkey ?? 'Control+Alt+S';
      safeLog('Initializing Hotkey: $hotkeyStr');
      
      // Basic parser for 'Control+Alt+S'
      List<HotKeyModifier> modifiers = [];
      if (hotkeyStr.contains('Control')) modifiers.add(HotKeyModifier.control);
      if (hotkeyStr.contains('Alt')) modifiers.add(HotKeyModifier.alt);
      if (hotkeyStr.contains('Shift')) modifiers.add(HotKeyModifier.shift);
      
      LogicalKeyboardKey key = LogicalKeyboardKey.keyS;
      if (hotkeyStr.endsWith('+S')) key = LogicalKeyboardKey.keyS;
      // Note: We can expand this parser if needed
      
      HotKey hotKey = HotKey(
        key: key,
        modifiers: modifiers,
        scope: HotKeyScope.system,
      );

      hotKeyManager.unregister(hotKey); // Clean up if re-init
      hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          final manager = HotCornerManager();
          final config = ConfigService();
          config.isSuspended = !config.isSuspended;
          safeLog('Hotkey pressed. Suspended: ${config.isSuspended}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(config.isSuspended ? "Aplikacja zawieszona" : "Aplikacja wznowiona"),
              duration: const Duration(seconds: 1),
            )
          );
          setState(() {});
        },
      );
    } catch (e) {
      safeLog('Hotkey Error: $e');
    }
  }

  Future<void> _updateTrayMenu() async {
    try {
      // Small delay to ensure window state is propagated
      await Future.delayed(const Duration(milliseconds: 100));
      final isVisible = await windowManager.isVisible();
      final config = ConfigService();
      
      List<MenuItem> items = [
        MenuItem(
          key: 'toggle_window', 
          label: isVisible ? 'Pokaż okno' : 'Ukryj okno'
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'toggle_suspend', 
          label: config.isSuspended ? 'Wznów działanie' : 'Zawieś działanie'
        ),
        MenuItem(
          key: 'snooze_30', 
          label: 'Wyłącz na 30 min'
        ),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Zamknij aplikację'),
      ];
      await trayManager.setContextMenu(Menu(items: items));
    } catch (e) {
      safeLog('Failed to update tray menu: $e');
    }
  }

  Future<void> _initSystemTray() async {
    try {
      safeLog('Starting _initSystemTray (tray_manager)...');
      
      final String iconPath = p.join(Directory.systemTemp.path, 'ukotka_icon.ico');
      final String iconPngPath = p.join(Directory.systemTemp.path, 'ukotka_icon.png');
      
      final File tempIcon = File(iconPath);
      final File tempPng = File(iconPngPath);

      // Robustly write assets to exe dir
      final ByteData icoData = await rootBundle.load('assets/app_icon.ico');
      await tempIcon.writeAsBytes(icoData.buffer.asUint8List(), flush: true);
      
      final ByteData pngData = await rootBundle.load('assets/app_icon.png');
      await tempPng.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
      
      // Explicitly set window icon using PNG (more robust for taskbar)
      await windowManager.setIcon(iconPngPath); 
      
      // Set tray icon using ICO
      await trayManager.setIcon(iconPath);
      safeLog('Tray icon set successfully to: $iconPath');
      await _updateTrayMenu();
      await trayManager.setToolTip('uKotka Hot Corners');
      
      safeLog('SystemTray (tray_manager) successfully initialized');
    } catch (e, s) {
      safeLog('Tray Init Failed: $e\n$s');
    }
  }

  @override
  void onTrayIconMouseDown() async {
    safeLog('Tray Icon Clicked - Force restoring window');
    await _restoreWindow();
  }
  
  Future<void> _restoreWindow() async {
    await windowManager.setSkipTaskbar(false);
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
    _updateTrayMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    final config = ConfigService();
    if (menuItem.key == 'toggle_window') {
      if (await windowManager.isVisible()) {
        await windowManager.hide();
        await windowManager.setSkipTaskbar(true);
      } else {
        await _restoreWindow();
      }
    } else if (menuItem.key == 'toggle_suspend') {
      config.isSuspended = !config.isSuspended;
      await config.save();
      safeLog('Tray: Toggle Suspend -> ${config.isSuspended}');
    } else if (menuItem.key == 'snooze_30') {
      config.snoozeUntil = DateTime.now().add(const Duration(minutes: 30));
      safeLog('Tray: Snooze for 30m');
    } else if (menuItem.key == 'exit') {
      safeLog('Tray Menu: Exit');
      windowManager.destroy();
    }
    _updateTrayMenu();
    setState(() {}); // Update UI if open
  }

  @override
  Widget build(BuildContext context) {
    // If ready, show the actual app!
    if (_statusMessage == "Ready") {
      return MaterialApp(
        navigatorKey: navigatorKey,
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
      navigatorKey: navigatorKey,
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
