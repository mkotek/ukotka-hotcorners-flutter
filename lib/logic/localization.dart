import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localization/flutter_localization.dart';

class AppLocale {
  static const String title = 'title';
  static const String settings = 'settings';
  static const String about = 'about';
  static const String suspend = 'suspend';
  static const String resume = 'resume';
  static const String exit = 'exit';
  static const String cornerTopLeft = 'cornerTopLeft';
  static const String cornerTopRight = 'cornerTopRight';
  static const String cornerBottomLeft = 'cornerBottomLeft';
  static const String cornerBottomRight = 'cornerBottomRight';
  static const String actionNone = 'actionNone';
  static const String actionMonitorOff = 'actionMonitorOff';
  static const String actionScreenSaver = 'actionScreenSaver';
  static const String actionTaskView = 'actionTaskView';
  static const String actionStartMenu = 'actionStartMenu';
  static const String actionShowDesktop = 'actionShowDesktop';
  static const String actionActionCenter = 'actionActionCenter';
  static const String actionAeroShake = 'actionAeroShake';
  static const String actionLaunchApp = 'actionLaunchApp';
  static const String delay = 'delay';
  static const String size = 'size';
  static const String startup = 'startup';
  static const String monitorMode = 'monitorMode';
  static const String primaryOnly = 'primaryOnly';
  static const String independent = 'independent';
  static const String mirrored = 'mirrored';

  static const Map<String, dynamic> EN = {
    title: 'uKotka HotCorners',
    settings: 'Settings',
    about: 'About',
    suspend: 'Suspend',
    resume: 'Resume',
    exit: 'Exit',
    cornerTopLeft: 'Top Left',
    cornerTopRight: 'Top Right',
    cornerBottomLeft: 'Bottom Left',
    cornerBottomRight: 'Bottom Right',
    actionNone: 'None',
    actionMonitorOff: 'Turn off monitor',
    actionScreenSaver: 'Start screensaver',
    actionTaskView: 'Task View',
    actionStartMenu: 'Start Menu',
    actionShowDesktop: 'Show Desktop',
    actionActionCenter: 'Action Center',
    actionAeroShake: 'Aero Shake',
    actionLaunchApp: 'Launch App',
    delay: 'Delay (ms)',
    size: 'Size (px)',
    startup: 'Launch at startup',
    monitorMode: 'Monitor Mode',
    primaryOnly: 'Primary monitor only',
    independent: 'Independent actions for each monitor',
    mirrored: 'Same actions on all monitors',
  };

  static const Map<String, dynamic> PL = {
    title: 'uKotka HotCorners',
    settings: 'Ustawienia',
    about: 'O aplikacji',
    suspend: 'Zawieś',
    resume: 'Wznów',
    exit: 'Zamknij',
    cornerTopLeft: 'Górny lewy',
    cornerTopRight: 'Górny prawy',
    cornerBottomLeft: 'Dolny lewy',
    cornerBottomRight: 'Dolny prawy',
    actionNone: 'Brak akcji',
    actionMonitorOff: 'Wyłącz monitory',
    actionScreenSaver: 'Włącz wygaszacz',
    actionTaskView: 'Widok zadań',
    actionStartMenu: 'Menu Start',
    actionShowDesktop: 'Pokaż pulpit',
    actionActionCenter: 'Centrum akcji',
    actionAeroShake: 'Aero Shake',
    actionLaunchApp: 'Uruchom aplikację',
    delay: 'Opóźnienie (ms)',
    size: 'Rozmiar (px)',
    startup: 'Uruchamiaj przy starcie systemu',
    monitorMode: 'Tryb monitorów',
    primaryOnly: 'Tylko główny monitor',
    independent: 'Osobne akcje dla każdego monitora',
    mirrored: 'Te same akcje na każdym monitorze',
  };
}
