enum HotCornerActionType {
  none,
  monitorOff,
  screenSaver,
  taskView,
  startMenu,
  showDesktop,
  actionCenter,
  aeroShake,
  launchApp,
  appSwitcher,
  powerToysRun,
  settings,
  snippingTool,
  taskManager,
  commandPalette,
  lockWorkstation,
}

class CornerConfig {
  final HotCornerActionType action;
  final String? appPath;
  final String? appArgs;
  final double cornerSize;
  final Duration dwellTime;

  CornerConfig({
    this.action = HotCornerActionType.none,
    this.appPath,
    this.appArgs,
    this.cornerSize = 10.0,
    this.dwellTime = const Duration(milliseconds: 500),
  });

  Map<String, dynamic> toJson() => {
    'action': action.index,
    'appPath': appPath,
    'appArgs': appArgs,
    'cornerSize': cornerSize,
    'dwellTime': dwellTime.inMilliseconds,
  };

  factory CornerConfig.fromJson(Map<String, dynamic> json) => CornerConfig(
    action: HotCornerActionType.values[json['action'] ?? 0],
    appPath: json['appPath'],
    appArgs: json['appArgs'],
    cornerSize: (json['cornerSize'] ?? 10.0).toDouble(),
    dwellTime: Duration(milliseconds: json['dwellTime'] ?? 500),
  );
}
