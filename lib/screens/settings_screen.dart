import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:flutter/services.dart';
import '../logic/localization.dart';
import '../logic/config_service.dart';
import '../models/corner_config.dart';
import '../logic/win32_utils.dart';
import '../main.dart'; // Import safeLog

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  final ConfigService _config = ConfigService();
  List<Display> _displays = [];
  String? _selectedDisplayId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDisplays();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDisplays() async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final primary = await screenRetriever.getPrimaryDisplay();
      
      // Sort displays by physical position: left-to-right, then top-to-bottom
      displays.sort((a, b) {
        final posA = a.visiblePosition ?? const Offset(0, 0);
        final posB = b.visiblePosition ?? const Offset(0, 0);
        if (posA.dx != posB.dx) return posA.dx.compareTo(posB.dx);
        return posA.dy.compareTo(posB.dy);
      });

      safeLog('Discovered ${displays.length} displays. Priority Order: ${displays.map((e) => e.id).toList()}');
      
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00C2FF),
          labelColor: const Color(0xFF00C2FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(LucideIcons.monitor), text: "Narożniki"),
            Tab(icon: Icon(LucideIcons.zap), text: "Zachowanie"),
            Tab(icon: Icon(LucideIcons.settings), text: "System"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.info),
            onPressed: () => _showAboutDialog(context),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: CORNERS
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildMonitorSection(),
              const SizedBox(height: 24),
              if (_selectedDisplayId != null) _buildCornerConfiguration(),
            ],
          ),
          // TAB 2: BEHAVIOR
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildBehaviorSettings(),
            ],
          ),
          // TAB 3: SYSTEM
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSystemSettings(),
              const Divider(height: 48, color: Colors.white12),
              _buildAboutSection(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonitorMap() {
    if (_displays.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("Układ wyświetlaczy", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              // Calculate bounding box of all displays
              double minX = double.infinity;
              double minY = double.infinity;
              double maxX = -double.infinity;
              double maxY = -double.infinity;

              for (var d in _displays) {
                final pos = d.visiblePosition ?? Offset.zero;
                final size = d.size ?? Size.zero;
                if (pos.dx < minX) minX = pos.dx;
                if (pos.dy < minY) minY = pos.dy;
                if (pos.dx + size.width > maxX) maxX = pos.dx + size.width;
                if (pos.dy + size.height > maxY) maxY = pos.dy + size.height;
              }

              final totalWidth = maxX - minX;
              final totalHeight = maxY - minY;
              
              // Scale factor to fit width but keep aspect ratio
              final double scale = (constraints.maxWidth - 40) / totalWidth;
              final double mapHeight = totalHeight * scale;

              return SizedBox(
                width: constraints.maxWidth,
                height: mapHeight + 20,
                child: Stack(
                  children: _displays.map((d) {
                    final pos = d.visiblePosition ?? Offset.zero;
                    final size = d.size ?? Size.zero;
                    final isSelected = d.id.toString() == _selectedDisplayId;
                    final displayNum = Win32Utils.getDisplayNumber(d.id.toString());

                    return Positioned(
                      left: (pos.dx - minX) * scale,
                      top: (pos.dy - minY) * scale,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDisplayId = d.id.toString()),
                        child: Container(
                          width: size.width * scale,
                          height: size.height * scale,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF107C10) : Colors.white12,
                            border: Border.all(
                              color: isSelected ? Colors.greenAccent : Colors.white24,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  displayNum.toString(),
                                  style: TextStyle(
                                    fontSize: 24 * (size.height / 1080), 
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Corner Indicators
                              ...List.generate(4, (index) {
                                final key = "${d.id}_$index";
                                final hasAction = _config.configs[key]?.action != null && _config.configs[key]?.action != HotCornerActionType.none;
                                if (!hasAction) return const SizedBox();
                                
                                // Color logic based on action (Windows-like palette)
                                Color cornerColor = Colors.yellow;
                                final action = _config.configs[key]?.action;
                                if (action == HotCornerActionType.showDesktop) cornerColor = Colors.blueAccent;
                                if (action == HotCornerActionType.lockWorkstation) cornerColor = Colors.redAccent;
                                if (action == HotCornerActionType.taskView) cornerColor = Colors.orangeAccent;
                                if (action == HotCornerActionType.monitorOff) cornerColor = Colors.deepPurpleAccent;
                                if (action == HotCornerActionType.startMenu) cornerColor = Colors.blue;

                                return Positioned(
                                  left: (index == 0 || index == 2) ? 2 : null,
                                  right: (index == 1 || index == 3) ? 2 : null,
                                  top: (index == 0 || index == 1) ? 2 : null,
                                  bottom: (index == 2 || index == 3) ? 2 : null,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: cornerColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  Widget _buildMonitorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tryb pracy monitorów", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<MonitorMode>(
          value: _config.monitorMode,
          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
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
          _buildMonitorMap(), // ADDED: Visual Monitor Map
          const SizedBox(height: 24),
          const Text("Aktywne ustawienia dla wyświetlacza:"),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDisplayId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: _displays.map((d) {
              final displayName = Win32Utils.getFriendlyNameForDisplay(d.id.toString());
              
              String label = displayName;
              if (d.visiblePosition?.dx == 0 && d.visiblePosition?.dy == 0) {
                label += " [Główny]";
              }
              if (d.size != null) {
                label += " (${d.size.width.toInt()}x${d.size.height.toInt()})";
              }

              return DropdownMenuItem(
                value: d.id.toString(), 
                child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (val) {
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
        const Text("Akcje narożników", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.8, 
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: config.action != HotCornerActionType.none ? const Color(0xFF00C2FF) : Colors.white24, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    _getActionLabel(config.action),
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
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

  Widget _buildBehaviorSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Responsywność i Overlay", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("Pokaż nakładkę wizualną (Overlay)"),
          subtitle: const Text("Błysk w rogu potwierdzający aktywację"),
          value: _config.showOverlay,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.showOverlay = val);
            _config.save();
          },
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("Opóźnienie między akcjami (Cooldown)", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("Opóźnienie między akcjami (Cooldown)", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text("Minimalny odstęp czasu między kolejnymi wywołaniami akcji (zapobiega migotaniu).", style: TextStyle(fontSize: 12, color: Colors.white54)),
        ),
        Slider(
          value: _config.actionCooldownMs.toDouble(),
          min: 500,
          max: 5000,
          divisions: 9, 
          label: "${_config.actionCooldownMs}ms",
          onChanged: (val) {
             setState(() => _config.actionCooldownMs = val.toInt());
             _config.save();
          },
        ),
        const SizedBox(height: 24),
        const Text("Skróty i zawieszanie", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(LucideIcons.keyboard, color: Color(0xFF00C2FF)),
          title: const Text("Zmień skrót zawieszania"),
          subtitle: Text("Obecny: ${_config.suspendHotkey ?? 'Control+Alt+S'}"),
          onTap: () => _showHotkeyChanger(),
        ),
        const SizedBox(height: 16),
        const Text("Snooze (Tymczasowe uśpienie)", style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSnoozeButton("5 min", 5),
            _buildSnoozeButton("15 min", 15),
            _buildSnoozeButton("30 min", 30),
            _buildSnoozeButton("Reset", 0),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Uruchamianie i Zamykanie", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        SwitchListTile(
          title: const Text("Zamykaj do traya (paska zadań)"),
          value: _config.minimizeOnClose,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.minimizeOnClose = val);
            _config.save();
          },
        ),
        SwitchListTile(
          title: const Text("Pytaj o akcję przy zamknięciu"),
          value: !_config.dontAskExit,
          activeTrackColor: const Color(0xFF00C2FF),
          onChanged: (val) {
            setState(() => _config.dontAskExit = !val);
            _config.save();
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.cat, color: Color(0xFF00C2FF), size: 32),
            SizedBox(width: 12),
            Text('uKotka HotCorners', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Wersja 1.3.0'),
        const SizedBox(height: 12),
        const Text('Prosta i wydajna aplikacja do obsługi gorących narożników na Windows.'),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => launchUrl(Uri.parse('https://ukotka.com')),
          child: const Text('https://ukotka.com', style: TextStyle(color: Color(0xFF00C2FF), decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'uKotka HotCorners'),
          child: const Text("Pokaż licencje"),
        ),
      ],
    );
  }

  Widget _buildSnoozeButton(String label, int minutes) {
    bool isActive = _config.snoozeUntil != null && _config.snoozeUntil!.isAfter(DateTime.now());
    return ElevatedButton(
      onPressed: () {
        setState(() {
          if (minutes == 0) {
            _config.snoozeUntil = null;
          } else {
            _config.snoozeUntil = DateTime.now().add(Duration(minutes: minutes));
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(minutes == 0 ? "Wznowiono działanie" : "Aplikacja uśpiona na $minutes min")));
      },
      style: ElevatedButton.styleFrom(backgroundColor: isActive && minutes > 0 ? Colors.blueGrey : null, padding: const EdgeInsets.symmetric(horizontal: 12)),
      child: Text(label),
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
      case HotCornerActionType.commandPalette: return "Paleta poleceń (Win+Alt+Space)";
      case HotCornerActionType.lockWorkstation: return "Zablokuj komputer (Win+L)";
    }
  }

  void _showCornerDialog(String label, String key, CornerConfig config, int index) {
    // Find the current display object to get its position
    final currentDisplay = _displays.firstWhere(
      (d) => d.id.toString() == _selectedDisplayId, 
      orElse: () => _displays.first
    );

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
            void updatePreview(double size) {
              final pos = currentDisplay.visiblePosition ?? const Offset(0, 0);
              final sz = currentDisplay.size;
              
              Offset cornerPos = pos;
              if (index == 1) cornerPos = Offset(pos.dx + sz.width, pos.dy);
              if (index == 2) cornerPos = Offset(pos.dx, pos.dy + sz.height);
              if (index == 3) cornerPos = Offset(pos.dx + sz.width, pos.dy + sz.height);
              
              showCornerPreview(index, size, cornerPos);
            }

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
                        decoration: const InputDecoration(labelText: "Parametry (Optional)"),
                        onChanged: (v) => tempArgs = v,
                        controller: TextEditingController(text: tempArgs),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Rozmiar: ${tempSize.toInt()}px"),
                        Slider(
                          value: tempSize,
                          min: 5,
                          max: 150,
                          onChanged: (v) {
                            setDialogState(() => tempSize = v);
                            updatePreview(v);
                          },
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Opóźnienie (Dwell Time): ${tempDelay}ms"),
                        Slider(
                          value: tempDelay.toDouble(),
                          min: 0,
                          max: 3000,
                          divisions: 30,
                          onChanged: (v) => setDialogState(() => tempDelay = v.toInt()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text("Podgląd obszaru aktywnego:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(color: const Color(0xFF1E1E1E), border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
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
                                ),
                              ),
                            ),
                            const Positioned(bottom: 8, right: 8, child: Text("Symulacja 150px", style: TextStyle(color: Colors.white38, fontSize: 10))),
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
                  if (keyLabel != "Control" && keyLabel != "Alt" && keyLabel != "Shift") keys.add(keyLabel);
                  if (keys.isNotEmpty) setDialogState(() => currentKeys = keys.join("+"));
                }
              },
              child: AlertDialog(
                title: const Text("Ustaw nowy skrót"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Naciśnij kombinację klawiszy (np. Ctrl+Alt+S)"),
                    const SizedBox(height: 20),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.blue), borderRadius: BorderRadius.circular(8)), child: Text(currentKeys.isEmpty ? "Czekam na klawisze..." : currentKeys, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
                  TextButton(
                    onPressed: () {
                      if (currentKeys.isNotEmpty) {
                        setState(() { _config.suspendHotkey = currentKeys; _config.save(); });
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
    // Legacy dialog kept as fallback or detailed view
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('O Programie'), content: _buildAboutSection(), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Zamknij"))]));
  }
}
