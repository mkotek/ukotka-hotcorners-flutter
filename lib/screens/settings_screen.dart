import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:screen_retriever/screen_retriever.dart';
import '../logic/localization.dart';
import '../logic/config_service.dart';
import '../models/corner_config.dart';

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
    final displays = await screenRetriever.getAllDisplays();
    setState(() {
      _displays = displays;
      if (_displays.isNotEmpty) {
        _selectedDisplayId = _displays.first.id.toString();
      }
    });
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
            items: _displays.map((d) => DropdownMenuItem(value: d.id.toString(), child: Text(d.name ?? "Monitor ${d.id}"))).toList(),
            onChanged: (val) => setState(() => _selectedDisplayId = val),
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
          childAspectRatio: 2.5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
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
      onTap: () => _showCornerDialog(label, key, config),
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
    }
  }

  void _showCornerDialog(String label, String key, CornerConfig config) {
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
      ],
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
