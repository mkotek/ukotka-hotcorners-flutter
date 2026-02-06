import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import '../models/corner_config.dart';
import '../main.dart'; // Import safeLog

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
  
  bool get hasConfig => configs.isNotEmpty;

  bool launchAtStartup = false;
  String? suspendHotkey;
  bool isSuspended = false;
  DateTime? snoozeUntil;
  bool minimizeOnClose = true;
  bool dontAskExit = false;

  bool get effectivelySuspended {
    if (isSuspended) return true;
    if (snoozeUntil != null && DateTime.now().isBefore(snoozeUntil!)) return true;
    return false;
  }

  Future<void> init() async {
    await _load();
  }

  Future<void> _load() async {
    try {
      final file = _settingsFile;
      safeLog('Loading settings from: ${file.path}');
      if (!await file.exists()) {
        safeLog('Settings file not found, using defaults');
        return;
      }

      final contents = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(contents);

      monitorMode = MonitorMode.values[data['monitorMode'] ?? 0];
      targetDisplayId = data['targetDisplayId'];
      launchAtStartup = data['launchAtStartup'] ?? false;
      suspendHotkey = data['suspendHotkey'] ?? 'Control+Alt+S';
      isSuspended = data['isSuspended'] ?? false;
      minimizeOnClose = data['minimizeOnClose'] ?? true;
      dontAskExit = data['dontAskExit'] ?? false;
      
      if (data['configs'] != null) {
        final Map<String, dynamic> decoded = data['configs'];
        configs = decoded.map((key, value) => MapEntry(key, CornerConfig.fromJson(value)));
      }
      safeLog('Settings loaded successfully. MonitorMode: $monitorMode, Configs: ${configs.length}');
    } catch (e, s) {
      safeLog('Error loading settings: $e\n$s');
    }
  }

  Future<void> save() async {
    try {
      safeLog('Saving settings...');
      final Map<String, dynamic> data = {
        'monitorMode': monitorMode.index,
        'targetDisplayId': targetDisplayId,
        'launchAtStartup': launchAtStartup,
        'suspendHotkey': suspendHotkey,
        'isSuspended': isSuspended,
        'minimizeOnClose': minimizeOnClose,
        'dontAskExit': dontAskExit,
        'configs': configs.map((key, value) => MapEntry(key, value.toJson())),
      };

      final String encoded = jsonEncode(data);
      await _settingsFile.writeAsString(encoded);
      safeLog('Settings saved. LaunchAtStartup: $launchAtStartup');
    } catch (e, s) {
      safeLog('Error saving settings: $e\n$s');
    }
  }

  void setSuspended(bool value) {
    isSuspended = value;
  }
}
