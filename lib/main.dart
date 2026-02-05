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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    await windowManager.hide(); // Start hidden in tray by default
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

  Future<void> _initSystemTray() async {
    String iconPath = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    
    await _systemTray.initSystemTray(
      title: "uKotka HotCorners",
      iconPath: iconPath,
    );

    // Show settings on first launch or if specifically requested
    if (!ConfigService().hasConfig || ConfigService().launchAtStartup == false) {
       windowManager.show();
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
