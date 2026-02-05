import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
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

  File get _settingsFile {
    final exePath = Platform.resolvedExecutable;
    final exeDir = p.dirname(exePath);
    return File(p.join(exeDir, 'settings.json'));
  }
  
  // Settings
  MonitorMode monitorMode = MonitorMode.primaryOnly;
  String? targetDisplayId;
  Map<String, CornerConfig> configs = {}; // key: displayId_cornerIndex
  bool launchAtStartup = false;
  String? suspendHotkey;
  bool isSuspended = false;

  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final file = _settingsFile;
      if (!await file.exists()) return;

      final contents = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(contents);

      monitorMode = MonitorMode.values[data['monitorMode'] ?? 0];
      targetDisplayId = data['targetDisplayId'];
      launchAtStartup = data['launchAtStartup'] ?? false;
      suspendHotkey = data['suspendHotkey'] ?? 'Control+Alt+S';
      
      if (data['configs'] != null) {
        final Map<String, dynamic> decoded = data['configs'];
        configs = decoded.map((key, value) => MapEntry(key, CornerConfig.fromJson(value)));
      }
    } catch (e) {
      // Ignore errors for now or log properly
    }
  }

  Future<void> save() async {
    try {
      final Map<String, dynamic> data = {
        'monitorMode': monitorMode.index,
        'targetDisplayId': targetDisplayId,
        'launchAtStartup': launchAtStartup,
        'suspendHotkey': suspendHotkey,
        'configs': configs.map((key, value) => MapEntry(key, value.toJson())),
      };

      final String encoded = jsonEncode(data);
      await _settingsFile.writeAsString(encoded);
    } catch (e) {
      print("Error saving config: $e");
    }
  }

  void setSuspended(bool value) {
    isSuspended = value;
  }
}
