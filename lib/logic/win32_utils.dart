import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32Utils {
  /// Returns a map of Display Name (e.g. \\.\DISPLAY1) to Friendly Name (e.g. Dell U2515H)
  /// Reverted to EnumDisplayDevices for maximum compatibility with older win32 packages.
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
          
          // Get the monitor for this device
          if (EnumDisplayDevices(lpDeviceName, 0, monitor, 0) != 0) {
            String monitorString = monitor.ref.DeviceString;
            
            // If it's empty or generic, we try to use the DeviceID to find something better in Registry
            // Typically DeviceID for a monitor looks like: MONITOR\GSM3407\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001
            // The part after MONITOR\ is often the model name prefix.
            final deviceId = monitor.ref.DeviceID;
            if (deviceId.isNotEmpty && (monitorString.isEmpty || monitorString == "Generic PnP Monitor" || monitorString == "Monitor Standardowy")) {
                 final parts = deviceId.split('\\');
                 if (parts.length > 1) {
                   // e.g. "K27T52" from MONITOR\K27T52\...
                   monitorString = parts[1];
                 }
            }
            
            if (monitorString.isEmpty) {
              monitorString = "Monitor ($deviceName)";
            }
            
            names[deviceName] = monitorString;
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
      final names = getMonitorFriendlyNames();
      final friendlyName = names[displayId] ?? displayId;
      
      // Clean up common generic names if they still persisted
      if (friendlyName == "Generic PnP Monitor" || friendlyName == "Monitor Standardowy") {
        return "Monitor ($displayId)";
      }
      
      return "$friendlyName ($displayId)";
    } catch (_) {
      return displayId;
    }
  }
}
