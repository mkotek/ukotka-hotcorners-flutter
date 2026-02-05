import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:system_tray/system_tray.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:async';

import 'logic/localization.dart';
import 'logic/config_service.dart';
import 'logic/hot_corner_manager.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Services
  await ConfigService().init();
  await windowManager.ensureInitialized();
  // hotkey_manager does not need ensureInitialized in most versions, 
  // but some use waitUntilReady. Let's remove it if it fails.

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
    // Default hotkey fallback if none saved
    String keyStr = ConfigService().suspendHotkey ?? 'Control+Alt+S';
    // Simplified hotkey registration
    HotKey hotKey = HotKey(
      KeyCode.keyS,
      modifiers: [KeyModifier.control, KeyModifier.alt],
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
    // Update menu labels if needed
  }

  Future<void> _initSystemTray() async {
    await _systemTray.initTray(
      title: "uKotka HotCorners",
      iconPath: 'windows/runner/resources/app_icon.ico',
    );

    await _menu.buildFrom([
      MenuItemLabel(label: 'Ustawienia', onClicked: (menuItem) => windowManager.show()),
      MenuSeparator(),
      SubMenu(label: 'Zawieś działanie', children: [
        MenuItemLabel(label: 'Na 5 minut', onClicked: (_) => _toggleSuspension(const Duration(minutes: 5))),
        MenuItemLabel(label: 'Na 30 minut', onClicked: (_) => _toggleSuspension(const Duration(minutes: 30))),
        MenuItemLabel(label: 'Na 1 godzinę', onClicked: (_) => _toggleSuspension(const Duration(hours: 1))),
        MenuItemLabel(label: 'Na stałe', onClicked: (_) => _toggleSuspension()),
      ]),
      MenuItemLabel(label: 'Wznów działanie', onClicked: (_) {
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
