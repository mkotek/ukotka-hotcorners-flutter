import 'dart:async';
import 'dart:ffi';
import 'dart:ui';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'action_engine.dart';
import 'config_service.dart';
import '../models/corner_config.dart';
import '../main.dart'; // Import safeLog

enum HotCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  none,
}

class HotCornerManager {
  static final HotCornerManager _instance = HotCornerManager._internal();
  factory HotCornerManager() => _instance;
  HotCornerManager._internal();

  Timer? _timer;
  HotCorner _lastCorner = HotCorner.none;
  String? _lastDisplayId;
  DateTime? _discoveryTime;
  
  final ConfigService _config = ConfigService();

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _checkMousePosition());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkMousePosition() async {
    if (_config.effectivelySuspended) return;

    final pointer = calloc<POINT>();
    try {
      if (GetCursorPos(pointer) != 0) {
        final x = pointer.ref.x.toDouble();
        final y = pointer.ref.y.toDouble();

        final displays = await screenRetriever.getAllDisplays();
        final primaryDisplay = await screenRetriever.getPrimaryDisplay();
        Display? targetDisplay;
        HotCorner currentCorner = HotCorner.none;
        CornerConfig? activeConfig;

        for (final display in displays) {
          // Requirement #1: Monitor exclusion/inclusion logic
          if (_config.monitorMode == MonitorMode.primaryOnly && display.id != primaryDisplay.id) continue;
          if (_config.monitorMode == MonitorMode.independent && 
              _config.targetDisplayId != null && 
              _config.targetDisplayId != display.id.toString()) {
              // Note: If we are in "independent" mode but a specific monitor is pinned, 
              // we only check that monitor. If targetDisplayId is null, we check all (mirrored/independent).
              continue;
          }

          final displayRect = Rect.fromLTWH(
            display.visiblePosition?.dx ?? 0, 
            display.visiblePosition?.dy ?? 0, 
            display.size.width, 
            display.size.height
          );

          if (displayRect.contains(Offset(x, y))) {
            targetDisplay = display;
            
            // Check each corner with its specific size from config (Requirement #2)
            for (var corner in HotCorner.values) {
              if (corner == HotCorner.none) continue;
              
              final configKey = "${display.id}_${corner.index}";
              final config = _config.configs[configKey] ?? CornerConfig();
              
              if (_isInsideCorner(Offset(x, y), displayRect, corner, config.cornerSize)) {
                currentCorner = corner;
                activeConfig = config;
                break;
              }
            }
            if (currentCorner != HotCorner.none) break;
          }
        }

        // Logic for tracking "Dwell Time" (Requirement #3)
        if (currentCorner != HotCorner.none && (currentCorner != _lastCorner || targetDisplay?.id.toString() != _lastDisplayId)) {
          _lastCorner = currentCorner;
          _lastDisplayId = targetDisplay?.id.toString();
          _discoveryTime = DateTime.now();
        } else if (currentCorner == HotCorner.none) {
          _lastCorner = HotCorner.none;
          _lastDisplayId = null;
          _discoveryTime = null;
        }

        if (currentCorner != HotCorner.none && _discoveryTime != null && activeConfig != null) {
          final elapsed = DateTime.now().difference(_discoveryTime!);
          if (elapsed >= activeConfig.dwellTime) {
            safeLog('Corner triggered: $currentCorner on Display $targetDisplay');
            ActionEngine.execute(activeConfig);
            // Prevent multiple triggers by resetting discovery time into the future 
            // until the mouse leaves the corner.
            _discoveryTime = DateTime.now().add(const Duration(hours: 24)); 
          }
        }
      }
    } catch (e) {
      debugPrint("Error checking mouse position: $e");
    } finally {
      free(pointer);
    }
  }

  bool _isInsideCorner(Offset mousePos, Rect displayRect, HotCorner corner, double size) {
    switch (corner) {
      case HotCorner.topLeft:
        return mousePos.dx < displayRect.left + size && mousePos.dy < displayRect.top + size;
      case HotCorner.topRight:
        return mousePos.dx > displayRect.right - size && mousePos.dy < displayRect.top + size;
      case HotCorner.bottomLeft:
        return mousePos.dx < displayRect.left + size && mousePos.dy > displayRect.bottom - size;
      case HotCorner.bottomRight:
        return mousePos.dx > displayRect.right - size && mousePos.dy > displayRect.bottom - size;
      case HotCorner.none:
        return false;
    }
  }
}
