import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32Utils {
  /// Returns a map of GDI Name (e.g. \\.\DISPLAY1) to Friendly Name (e.g. DELL U2515H)
  static Map<String, String> getMonitorFriendlyNames() {
    final Map<String, String> names = {};
    
    final adapter = calloc<DISPLAY_DEVICE>();
    adapter.ref.cb = sizeOf<DISPLAY_DEVICE>();
    
    try {
      int i = 0;
      while (EnumDisplayDevices(nullptr, i, adapter, 0) != 0) {
        final deviceName = adapter.ref.DeviceName;
        final lpDeviceName = deviceName.toNativeUtf16();
        
        try {
          final monitor = calloc<DISPLAY_DEVICE>();
          monitor.ref.cb = sizeOf<DISPLAY_DEVICE>();
          
          if (EnumDisplayDevices(lpDeviceName, 0, monitor, 0) != 0) {
            String monitorString = monitor.ref.DeviceString;
            final deviceId = monitor.ref.DeviceID;
            
            // Extract model name from DeviceID (e.g. MONITOR\GSM3407\...)
            if (deviceId.isNotEmpty) {
                 final parts = deviceId.split('\\');
                 if (parts.length > 1 && (monitorString.contains("Generic") || monitorString.contains("Standardowy") || monitorString.isEmpty)) {
                   monitorString = parts[1]; // Often the hardware model string
                 }
            }
            
            if (monitorString.isNotEmpty) {
              names[deviceName] = monitorString;
            }
          }
          free(monitor);
        } finally {
          free(lpDeviceName);
        }
        i++;
      }
    } finally {
      free(adapter);
    }
    
    return names;
  }

  /// Returns a display index (1, 2, 3...) based on GDI name
  static int getDisplayNumber(String displayId) {
    // Usually \\.\DISPLAY1 -> 1
    final RegExp regExp = RegExp(r'DISPLAY(\d+)');
    final match = regExp.firstMatch(displayId);
    if (match != null) {
      return int.tryParse(match.group(1) ?? "0") ?? 0;
    }
    return 0;
  }

  static String getFriendlyNameForDisplay(String displayId) {
    try {
      final names = getMonitorFriendlyNames();
      final friendlyName = names[displayId] ?? "";
      final displayNum = getDisplayNumber(displayId);
      
      final label = "Wyświetlacz $displayNum";
      
      if (friendlyName.isEmpty || friendlyName == displayId) {
        return label;
      }
      
      return "$label: $friendlyName";
    } catch (_) {
      return displayId;
    }
  }
}
