import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32Utils {
  /// Returns a map of GDI Name (e.g. \\.\DISPLAY1) to Friendly Name (e.g. Dell U2515H)
  static Map<String, String> getMonitorFriendlyNames() {
    final Map<String, String> names = {};
    
    final adapter = calloc<DISPLAY_DEVICE>();
    adapter.ref.cb = sizeOf<DISPLAY_DEVICE>();
    
    try {
      int i = 0;
      while (EnumDisplayDevices(nullptr, i, adapter, 0) != 0) {
        final deviceName = adapter.ref.DeviceName; // e.g. \\.\DISPLAY1
        final lpDeviceName = deviceName.toNativeUtf16();
        
        try {
          final monitor = calloc<DISPLAY_DEVICE>();
          monitor.ref.cb = sizeOf<DISPLAY_DEVICE>();
          
          if (EnumDisplayDevices(lpDeviceName, 0, monitor, 0) != 0) {
            String monitorString = monitor.ref.DeviceString;
            final deviceId = monitor.ref.DeviceID;
            
            // Try to extract a hardware-specific ID segment if name is generic
            if (deviceId.isNotEmpty && (monitorString.isEmpty || monitorString.contains("Generic") || monitorString.contains("Standardowy") || monitorString.contains("PnP"))) {
                 final parts = deviceId.split('\\');
                 if (parts.length > 1) {
                   // Often parts[1] is the model code, e.g. "SKG3407"
                   monitorString = parts[1];
                 }
            }
            
            // Do NOT store the GDI name as the friendly name
            if (monitorString.isNotEmpty && monitorString != deviceName) {
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

  static String getFriendlyNameForDisplay(String displayId) {
    try {
      // Per user request: simplify to just "DISPLAY X"
      if (displayId.startsWith(r'\\.\')) {
        return displayId.substring(4); // e.g. "DISPLAY3"
      }
      return displayId;
    } catch (_) {
      return displayId;
    }
  }
}
