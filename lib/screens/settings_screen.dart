import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:flutter/services.dart';
import '../logic/localization.dart';
import '../logic/config_service.dart';
import '../models/corner_config.dart';
import '../main.dart'; // Import safeLog

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ConfigService _config = ConfigService();
  List<Display> _displays = [];
  String? _selectedDisplayId;

  @override
  void initState() {
    super.initState();
    _loadDisplays();
  }

  Future<void> _loadDisplays() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final primary = await screenRetriever.getPrimaryDisplay();
      
      safeLog('Discovered ${displays.length} displays. Primary ID: ${primary.id}');
      for (var d in displays) {
         safeLog(' - Display ID: ${d.id}, Name: ${d.name}, Size: ${d.size}');
      }

      setState(() {
        _displays = displays;
        if (_displays.isNotEmpty && _selectedDisplayId == null) {
          _selectedDisplayId = _displays.first.id.toString();
        }
      });
    } catch (e, s) {
      safeLog('Error loading displays: $e\n$s');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocale.title.getString(context)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildMonitorSection(),
          const SizedBox(height: 32),
          if (_selectedDisplayId != null) _buildCornerConfiguration(),
          const SizedBox(height: 32),
          _buildGeneralSettings(),
        ],
      ),
    );
  }

  Widget _buildMonitorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocale.monitorMode.getString(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<MonitorMode>(
          value: _config.monitorMode,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: MonitorMode.primaryOnly, child: Text(AppLocale.primaryOnly.getString(context))),
            DropdownMenuItem(value: MonitorMode.independent, child: Text(AppLocale.independent.getString(context))),
            DropdownMenuItem(value: MonitorMode.mirrored, child: Text(AppLocale.mirrored.getString(context))),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _config.monitorMode = val);
              _config.save();
            }
          },
        ),
        if (_config.monitorMode == MonitorMode.independent && _displays.length > 1) ...[
          const SizedBox(height: 16),
          const Text("Wybierz monitor do konfiguracji:"),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDisplayId,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _displays.map((d) {
              // Heuristic to extract hardware name (e.g. SKG3407) from ID if possible
              String hardwareName = "Monitor";
              if (d.id.toString().contains('MONITOR\\')) {
                try {
                  final parts = d.id.toString().split('\\');
                  if (parts.length > 1) hardwareName = parts[1];
                } catch (_) {}
              }

              // Combined Label: Hardware (Primary) - WindowsName
              String label = hardwareName;
              if (d.visiblePosition?.dx == 0 && d.visiblePosition?.dy == 0) {
                label += " (Główny)";
              }
              label += " - ${d.name ?? 'Device'}";

              return DropdownMenuItem(value: d.id.toString(), child: Text(label));
            }).toList(),
            onChanged: (val) {
              safeLog('Selected display for config changed to: $val');
              setState(() => _selectedDisplayId = val);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCornerConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Konfiguracja narożników", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.0, // Shorter buttons
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _buildCornerTile(AppLocale.cornerTopLeft.getString(context), 0, LucideIcons.arrow_up_left),
            _buildCornerTile(AppLocale.cornerTopRight.getString(context), 1, LucideIcons.arrow_up_right),
            _buildCornerTile(AppLocale.cornerBottomLeft.getString(context), 2, LucideIcons.arrow_down_left),
            _buildCornerTile(AppLocale.cornerBottomRight.getString(context), 3, LucideIcons.arrow_down_right),
          ],
        ),
      ],
    );
  }

  Widget _buildCornerTile(String label, int index, IconData icon) {
    final key = "${_selectedDisplayId}_$index";
    final config = _config.configs[key] ?? CornerConfig();

    return InkWell(
      onTap: () => _showCornerDialog(label, key, config, index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: config.action != HotCornerActionType.none ? const Color(0xFF00C2FF) : Colors.white12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: config.action != HotCornerActionType.none ? const Color(0xFF00C2FF) : Colors.white24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _getActionLabel(config.action),
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getActionLabel(HotCornerActionType type) {
    switch (type) {
      case HotCornerActionType.none: return AppLocale.actionNone.getString(context);
      case HotCornerActionType.monitorOff: return AppLocale.actionMonitorOff.getString(context);
      case HotCornerActionType.screenSaver: return AppLocale.actionScreenSaver.getString(context);
      case HotCornerActionType.taskView: return AppLocale.actionTaskView.getString(context);
      case HotCornerActionType.startMenu: return AppLocale.actionStartMenu.getString(context);
      case HotCornerActionType.showDesktop: return AppLocale.actionShowDesktop.getString(context);
      case HotCornerActionType.actionCenter: return AppLocale.actionActionCenter.getString(context);
      case HotCornerActionType.aeroShake: return AppLocale.actionAeroShake.getString(context);
      case HotCornerActionType.launchApp: return AppLocale.actionLaunchApp.getString(context);
      case HotCornerActionType.appSwitcher: return "Przełącznik okien (Alt+Tab)";
      case HotCornerActionType.powerToysRun: return "PowerToys Run (Alt+Space)";
      case HotCornerActionType.settings: return "Ustawienia Windows (Win+I)";
      case HotCornerActionType.snippingTool: return "Wycinanie i szkic (Win+Shift+S)";
      case HotCornerActionType.taskManager: return "Menedżer zadań (Ctrl+Shift+Esc)";
      case HotCornerActionType.commandPalette: return "Paleta poleceń (Ctrl+Alt+Space)";
    }
  }

  void _showCornerDialog(String label, String key, CornerConfig config, int index) {
    showDialog(
      context: context,
      builder: (context) {
        HotCornerActionType tempAction = config.action;
        double tempSize = config.cornerSize;
        int tempDelay = config.dwellTime.inMilliseconds;
        String tempPath = config.appPath ?? "";
        String tempArgs = config.appArgs ?? "";

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(label),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<HotCornerActionType>(
                      value: tempAction,
                      decoration: const InputDecoration(labelText: "Akcja"),
                      items: HotCornerActionType.values.map((v) => DropdownMenuItem(value: v, child: Text(_getActionLabel(v)))).toList(),
                      onChanged: (v) => setDialogState(() => tempAction = v!),
                    ),
                    if (tempAction == HotCornerActionType.launchApp) ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: const InputDecoration(labelText: "Ścieżka do aplikacji"),
                        onChanged: (v) => tempPath = v,
                        controller: TextEditingController(text: tempPath),
                      ),
                      TextField(
                        decoration: const InputDecoration(labelText: "Parametry"),
                        onChanged: (v) => tempArgs = v,
                        controller: TextEditingController(text: tempArgs),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text("Rozmiar: ${tempSize.toInt()}px")),
                        Expanded(
                          flex: 2,
                          child: Slider(
                            value: tempSize,
                            min: 1,
                            max: 100,
                            onChanged: (v) => setDialogState(() => tempSize = v),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: Text("Opóźnienie: ${tempDelay}ms")),
                        Expanded(
                          flex: 2,
                          child: Slider(
                            value: tempDelay.toDouble(),
                            min: 0,
                            max: 3000,
                            divisions: 30,
                            onChanged: (v) => setDialogState(() => tempDelay = v.toInt()),
                          ),
                        ),
                      ],
                    ),
                    
                    // PREVIEW VISUALIZATION
                    const SizedBox(height: 20),
                    const Text("Podgląd obszaru aktywnego:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: (index == 2 || index == 3) ? null : 0,
                              bottom: (index == 2 || index == 3) ? 0 : null,
                              left: (index == 1 || index == 3) ? null : 0,
                              right: (index == 1 || index == 3) ? 0 : null,
                              child: Container(
                                width: tempSize,
                                height: tempSize,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C2FF).withOpacity(0.5),
                                  border: Border.all(color: const Color(0xFF00C2FF), width: 1),
                                  borderRadius: BorderRadius.only(
                                    bottomRight: index == 0 ? const Radius.circular(4) : Radius.zero,
                                    bottomLeft: index == 1 ? const Radius.circular(4) : Radius.zero,
                                    topRight: index == 2 ? const Radius.circular(4) : Radius.zero,
                                    topLeft: index == 3 ? const Radius.circular(4) : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 8,
                              right: 8,
                              child: Text("Symulacja 150x150 px", 
                                style: TextStyle(color: Colors.white38, fontSize: 10)
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _config.configs[key] = CornerConfig(
                        action: tempAction,
                        appPath: tempPath,
                        appArgs: tempArgs,
                        cornerSize: tempSize,
                        dwellTime: Duration(milliseconds: tempDelay),
                      );
                    });
                    _config.save();
                    Navigator.pop(context);
                  },
                  child: const Text("Zapisz"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGeneralSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Ogólne", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SwitchListTile(
          title: Text(AppLocale.startup.getString(context)),
          value: _config.launchAtStartup,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.launchAtStartup = val);
            _config.save();
          },
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text("Zamykaj do traya (paska zadań)"),
          subtitle: const Text("Jeśli wyłączone, X całkowicie zamknie aplikację"),
          value: _config.minimizeOnClose,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.minimizeOnClose = val);
            _config.save();
          },
        ),
        SwitchListTile(
          title: const Text("Pytaj o akcję przy zamknięciu"),
          subtitle: const Text("Pokazuje wybór: Zamknij vs Tray"),
          value: !_config.dontAskExit,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.dontAskExit = !val);
            _config.save();
          },
        ),
        const SizedBox(height: 16),
        const Text("Skróty i zawieszanie", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(LucideIcons.keyboard, color: Color(0xFF00C2FF)),
          title: const Text("Zmień skrót zawieszania"),
          subtitle: Text("Obecny: ${_config.suspendHotkey ?? 'Control+Alt+S'}"),
          onTap: () => _showHotkeyChanger(),
        ),
        const SizedBox(height: 8),
        const Text("Snooze (Tymczasowe uśpienie)", style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSnoozeButton("5 min", 5),
            _buildSnoozeButton("15 min", 15),
            _buildSnoozeButton("30 min", 30),
            _buildSnoozeButton("60 min", 60),
            _buildSnoozeButton("Reset", 0),
          ],
        ),
      ],
    );
  }

  Widget _buildSnoozeButton(String label, int minutes) {
    bool isActive = _config.snoozeUntil != null && 
                    _config.snoozeUntil!.isAfter(DateTime.now());
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          if (minutes == 0) {
            _config.snoozeUntil = null;
          } else {
            _config.snoozeUntil = DateTime.now().add(Duration(minutes: minutes));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Aplikacja uśpiona na $minutes min"))
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? Colors.blueGrey : null,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }

  void _showHotkeyChanger() {
    String currentKeys = "";
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return RawKeyboardListener(
              focusNode: FocusNode()..requestFocus(),
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent) {
                  final keys = <String>{};
                  if (event.isControlPressed) keys.add("Control");
                  if (event.isAltPressed) keys.add("Alt");
                  if (event.isShiftPressed) keys.add("Shift");
                  
                  final keyLabel = event.logicalKey.keyLabel;
                  if (keyLabel != "Control" && keyLabel != "Alt" && keyLabel != "Shift") {
                    keys.add(keyLabel);
                  }
                  
                  if (keys.isNotEmpty) {
                    setDialogState(() {
                      currentKeys = keys.join("+");
                    });
                  }
                }
              },
              child: AlertDialog(
                title: const Text("Ustaw nowy skrót"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Naciśnij kombinację klawiszy (np. Ctrl+Alt+S)"),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentKeys.isEmpty ? "Czekam na klawisze..." : currentKeys,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Anuluj"),
                  ),
                  TextButton(
                    onPressed: () {
                      if (currentKeys.isNotEmpty) {
                        setState(() {
                          _config.suspendHotkey = currentKeys;
                          _config.save();
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Zapisz"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'uKotka HotCorners',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(LucideIcons.cat, color: Color(0xFF00C2FF), size: 48),
      children: [
        const Text('Prosta i wydajna aplikacja do obsługi gorących narożników.'),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => launchUrl(Uri.parse('https://ukotka.com')),
          child: const Text(
            'https://ukotka.com',
            style: TextStyle(color: Color(0xFF00C2FF), decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }
}
