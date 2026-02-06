import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/corner_config.dart';
import '../main.dart'; // Import safeLog

class ActionEngine {
  static Future<void> execute(CornerConfig config) async {
    safeLog('Executing action: ${config.action}');
    switch (config.action) {
      case HotCornerActionType.monitorOff:
        safeLog('Sending SC_MONITORPOWER (standby)...');
        // Using 1 (standby) instead of 2 (off) for better compatibility and wake-up
        SendMessage(HWND_BROADCAST, WM_SYSCOMMAND, SC_MONITORPOWER, 1);
        break;
      case HotCornerActionType.screenSaver:
        _sendMessage(WM_SYSCOMMAND, SC_SCREENSAVE, 0);
        break;
      case HotCornerActionType.taskView:
        // Win + Tab
        _sendKeyCombo([VK_LWIN, VK_TAB]);
        break;
      case HotCornerActionType.startMenu:
        // Ctrl + Esc
        _sendKeyCombo([VK_LCONTROL, VK_ESCAPE]);
        break;
      case HotCornerActionType.showDesktop:
        // Toggle Desktop via shell command
        safeLog('Running PowerShell ToggleDesktop...');
        Process.run('powershell', ['-Command', '(New-Object -ComObject shell.application).ToggleDesktop()']);
        break;
      case HotCornerActionType.actionCenter:
        // Win + A
        _sendKeyCombo([VK_LWIN, 0x41]); // 0x41 is 'A'
        break;
      case HotCornerActionType.aeroShake:
        // Win + Home
        _sendKeyCombo([VK_LWIN, VK_HOME]);
        break;
      case HotCornerActionType.launchApp:
        if (config.appPath != null) {
          safeLog('Launching app: ${config.appPath} with args: ${config.appArgs}');
          Process.start(config.appPath!, config.appArgs?.split(' ') ?? []);
        } else {
          safeLog('LaunchApp action targeted but appPath is null');
        }
        break;
      case HotCornerActionType.appSwitcher:
        // Alt + Tab
        _sendKeyCombo([VK_LMENU, VK_TAB]);
        break;
      case HotCornerActionType.powerToysRun:
        // Alt + Space
        _sendKeyCombo([VK_LMENU, VK_SPACE]);
        break;
      case HotCornerActionType.settings:
        // Win + I
        _sendKeyCombo([VK_LWIN, 0x49]); // 'I'
        break;
      case HotCornerActionType.none:
        break;
    }
  }

  static void _sendMessage(int msg, int wParam, int lParam) {
    SendMessage(HWND_BROADCAST, msg, wParam, lParam);
  }

  static void _sendKeyCombo(List<int> keys) {
    final inputs = calloc<INPUT>(keys.length * 2);
    try {
      // Key Down
      for (var i = 0; i < keys.length; i++) {
        inputs[i].type = INPUT_KEYBOARD;
        inputs[i].ki.wVk = keys[i];
      }
      // Key Up (Reverse Order)
      for (var i = 0; i < keys.length; i++) {
        final keyIdx = keys.length - 1 - i;
        inputs[keys.length + i].type = INPUT_KEYBOARD;
        inputs[keys.length + i].ki.wVk = keys[keyIdx];
        inputs[keys.length + i].ki.dwFlags = KEYEVENTF_KEYUP;
      }
      SendInput(keys.length * 2, inputs, sizeOf<INPUT>());
    } finally {
      free(inputs);
    }
  }
}
