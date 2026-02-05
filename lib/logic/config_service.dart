import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/corner_config.dart';

enum MonitorMode {
  primaryOnly,
  independent,
  mirrored,
}

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  late SharedPreferences _prefs;
  
  // Settings
  MonitorMode monitorMode = MonitorMode.primaryOnly;
  String? targetDisplayId;
  Map<String, CornerConfig> configs = {}; // key: displayId_cornerIndex
  bool launchAtStartup = false;
  String? suspendHotkey;
  bool isSuspended = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    monitorMode = MonitorMode.values[_prefs.getInt('monitorMode') ?? 0];
    targetDisplayId = _prefs.getString('targetDisplayId');
    launchAtStartup = _prefs.getBool('launchAtStartup') ?? false;
    suspendHotkey = _prefs.getString('suspendHotkey') ?? 'Control+Alt+S';
    
    final String? jsonConfigs = _prefs.getString('configs');
    if (jsonConfigs != null) {
      final Map<String, dynamic> decoded = jsonDecode(jsonConfigs);
      configs = decoded.map((key, value) => MapEntry(key, CornerConfig.fromJson(value)));
    }
  }

  Future<void> save() async {
    await _prefs.setInt('monitorMode', monitorMode.index);
    if (targetDisplayId != null) await _prefs.setString('targetDisplayId', targetDisplayId!);
    await _prefs.setBool('launchAtStartup', launchAtStartup);
    if (suspendHotkey != null) await _prefs.setString('suspendHotkey', suspendHotkey!);
    
    final String encoded = jsonEncode(configs.map((key, value) => MapEntry(key, value.toJson())));
    await _prefs.setString('configs', encoded);
  }

  void setSuspended(bool value) {
    isSuspended = value;
  }
}
