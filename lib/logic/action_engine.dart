import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/corner_config.dart';

class ActionEngine {
  static Future<void> execute(CornerConfig config) async {
    switch (config.action) {
      case HotCornerActionType.monitorOff:
        _sendMessage(WM_SYSCOMMAND, SC_MONITORPOWER, 2);
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
          Process.start(config.appPath!, config.appArgs?.split(' ') ?? []);
        }
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
      // Key Up
      for (var i = 0; i < keys.length; i++) {
        inputs[keys.length + i].type = INPUT_KEYBOARD;
        inputs[keys.length + i].ki.wVk = keys[i];
        inputs[keys.length + i].ki.dwFlags = KEYEVENTF_KEYUP;
      }
      SendInput(keys.length * 2, inputs, sizeOf<INPUT>());
    } finally {
      free(inputs);
    }
  }
}
