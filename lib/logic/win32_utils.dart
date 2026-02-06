import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32Utils {
  static Map<String, String> getMonitorFriendlyNames() {
    final Map<String, String> names = {};
    
    // First, map DISPLAY names to Monitor names
    // We use EnumDisplayDevices to find the monitor string for each adapter
    
    final adapter = calloc<DISPLAY_DEVICE>();
    adapter.ref.cb = sizeOf<DISPLAY_DEVICE>();
    
    int i = 0;
    while (EnumDisplayDevices(nullptr, i, adapter, 0) != 0) {
      final deviceName = adapter.ref.DeviceName;
      
      // Now get the monitor for this device
      final monitor = calloc<DISPLAY_DEVICE>();
      monitor.ref.cb = sizeOf<DISPLAY_DEVICE>();
      
      if (EnumDisplayDevices(deviceName, 0, monitor, 0) != 0) {
        final monitorString = monitor.ref.DeviceString;
        names[deviceName] = monitorString;
      }
      
      i++;
      free(monitor);
    }
    free(adapter);
    
    return names;
  }

  static String getFriendlyNameForDisplay(String displayId) {
    // displayId is usually something like \\.\DISPLAY1
    final names = getMonitorFriendlyNames();
    return names[displayId] ?? displayId;
  }
}
