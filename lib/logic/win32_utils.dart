import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class Win32Utils {
  /// Returns a map of Display Name (e.g. \\.\DISPLAY1) to Friendly Name (e.g. Dell U2515H)
  static Map<String, String> getMonitorFriendlyNames() {
    final Map<String, String> names = {};
    
    // We use QueryDisplayConfig to get the most accurate hardware names (e.g. K27T52)
    // This is more complex but matches the user's requirement.
    
    final pNumPathArrayElements = calloc<Uint32>();
    final pNumModeInfoArrayElements = calloc<Uint32>();
    
    try {
      // 1. Get the buffer sizes
      final flags = QDC_ONLY_ACTIVE_PATHS;
      int result = GetDisplayConfigBufferSizes(flags, pNumPathArrayElements, pNumModeInfoArrayElements);
      
      if (result == ERROR_SUCCESS) {
        final pathArray = calloc<DISPLAYCONFIG_PATH_INFO>(pNumPathArrayElements.value);
        final modeArray = calloc<DISPLAYCONFIG_MODE_INFO>(pNumModeInfoArrayElements.value);
        
        // 2. Query the config
        result = QueryDisplayConfig(flags, pNumPathArrayElements, modeArray, pNumModeInfoArrayElements, modeArray, nullptr);
        
        if (result == ERROR_SUCCESS) {
          for (int i = 0; i < pNumPathArrayElements.value; i++) {
             // 3. For each path, get the target name
             final targetName = calloc<DISPLAYCONFIG_TARGET_DEVICE_NAME>();
             targetName.ref.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
             targetName.ref.header.size = sizeOf<DISPLAYCONFIG_TARGET_DEVICE_NAME>();
             targetName.ref.header.adapterId.LowPart = pathArray[i].targetInfo.adapterId.LowPart;
             targetName.ref.header.adapterId.HighPart = pathArray[i].targetInfo.adapterId.HighPart;
             targetName.ref.header.id = pathArray[i].targetInfo.id;
             
             if (DisplayConfigGetDeviceInfo(targetName.cast()) == ERROR_SUCCESS) {
                // This is the "DeviceString" from the hardware
                final friendlyName = targetName.ref.monitorFriendlyDeviceName;
                
                // We also need the GDI device name (\\.\DISPLAY1) to map it back
                final gdiName = calloc<DISPLAYCONFIG_SOURCE_DEVICE_NAME>();
                gdiName.ref.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
                gdiName.ref.header.size = sizeOf<DISPLAYCONFIG_SOURCE_DEVICE_NAME>();
                gdiName.ref.header.adapterId.LowPart = pathArray[i].sourceInfo.adapterId.LowPart;
                gdiName.ref.header.adapterId.HighPart = pathArray[i].sourceInfo.adapterId.HighPart;
                gdiName.ref.header.id = pathArray[i].sourceInfo.id;
                
                if (DisplayConfigGetDeviceInfo(gdiName.cast()) == ERROR_SUCCESS) {
                  names[gdiName.ref.viewGdiDeviceName] = friendlyName;
                }
                free(gdiName);
             }
             free(targetName);
          }
        }
        free(pathArray);
        free(modeArray);
      }
    } catch (e) {
      // Fallback to simpler method if something fails
    } finally {
      free(pNumPathArrayElements);
      free(pNumModeInfoArrayElements);
    }

    // Fallback: If map is empty, use EnumDisplayDevices
    if (names.isEmpty) {
      final adapter = calloc<DISPLAY_DEVICE>();
      adapter.ref.cb = sizeOf<DISPLAY_DEVICE>();
      int i = 0;
      while (EnumDisplayDevices(nullptr, i, adapter, 0) != 0) {
        final deviceName = adapter.ref.DeviceName;
        final lpDeviceName = deviceName.toNativeUtf16();
        final monitor = calloc<DISPLAY_DEVICE>();
        monitor.ref.cb = sizeOf<DISPLAY_DEVICE>();
        if (EnumDisplayDevices(lpDeviceName, 0, monitor, 0) != 0) {
            names[deviceName] = monitor.ref.DeviceString;
        }
        free(monitor);
        free(lpDeviceName);
        i++;
      }
      free(adapter);
    }
    
    return names;
  }

  static String getFriendlyNameForDisplay(String displayId) {
    try {
      final names = getMonitorFriendlyNames();
      // displayId is e.g. \\.\DISPLAY1
      return names[displayId] ?? displayId;
    } catch (_) {
      return displayId;
    }
  }
}
