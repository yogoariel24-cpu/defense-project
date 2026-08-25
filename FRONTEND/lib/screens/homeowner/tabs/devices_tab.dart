import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';

class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key});

  void _showAddDeviceDialog(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context, listen: false);
    final nameCtrl = TextEditingController();
    final identifierCtrl = TextEditingController();
    final ipCtrl = TextEditingController(text: '192.168.1.120');
    final locCtrl = TextEditingController(text: 'Living Room');
    String selectedType = 'SMART_LIGHT';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: AppTheme.primaryCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Provision IoT Device', style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Device Name (e.g. Porch Light) *')),
                    const SizedBox(height: 12),
                    TextField(controller: identifierCtrl, decoration: const InputDecoration(labelText: 'Hardware Identifier (e.g. ESP32_LGT_02) *')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.primarySurface,
                      decoration: const InputDecoration(labelText: 'Device Type'),
                      items: const [
                        DropdownMenuItem(value: 'SMART_LIGHT', child: Text('Smart Light (Relay / PWM)')),
                        DropdownMenuItem(value: 'ESP32_CAM', child: Text('ESP32-CAM AI Camera')),
                        DropdownMenuItem(value: 'MOTION_SENSOR', child: Text('PIR Motion Sensor')),
                        DropdownMenuItem(value: 'LIGHT_SENSOR', child: Text('LDR Light Sensor')),
                        DropdownMenuItem(value: 'ESP32', child: Text('ESP32 Core Hub')),
                      ],
                      onChanged: (v) => setModalState(() => selectedType = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Room / Location Name')),
                    const SizedBox(height: 12),
                    TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP Address')),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameCtrl.text.trim().isEmpty || identifierCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fill all mandatory fields'), backgroundColor: AppTheme.statusWarning),
                                );
                                return;
                              }

                              final success = await houseProvider.addDevice({
                                'name': nameCtrl.text.trim(),
                                'device_identifier': identifierCtrl.text.trim(),
                                'type': selectedType,
                                'ip_address': ipCtrl.text.trim(),
                                'specific_config': {
                                  'location_name': locCtrl.text.trim(),
                                },
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success ? 'Device registered successfully.' : 'Failed to register device.'),
                                    backgroundColor: success ? AppTheme.statusSafe : AppTheme.statusDanger,
                                  ),
                                );
                              }
                            },
                            child: const Text('Add Device'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final devices = houseProvider.devices;

    return RefreshIndicator(
      onRefresh: houseProvider.fetchDevices,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connected Hardware',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Provision Device'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  onPressed: () => _showAddDeviceDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (devices.isEmpty)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.devices_outlined, color: AppTheme.textMuted, size: 36),
                        SizedBox(height: 10),
                        Text('No IoT devices registered yet.', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                        Text('Tap "Provision Device" to connect ESP32, Sensors or Lights.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final d = devices[i];
                  final typeIcon = _iconForType(d.type);
                  final typeColor = _colorForType(d.type);

                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  d.type.replaceAll('_', ' '),
                                  if (d.locationName != null) '• ${d.locationName}',
                                  if (d.ipAddress != null) '• ${d.ipAddress}',
                                ].join(' '),
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              if (d.type == 'SMART_LIGHT' && d.brightness != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Brightness: ${d.brightness}% • ${d.isOn == true ? "ON" : "OFF"}',
                                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                              if (d.type == 'LIGHT_SENSOR' && d.currentLux != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${d.currentLux!.toStringAsFixed(1)} Lux  (Threshold: ${d.thresholdLux?.toStringAsFixed(0)} Lux)',
                                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatBadge(
                          label: d.status,
                          color: d.isOnline ? AppTheme.statusSafe : AppTheme.statusDanger,
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'ESP32': return Icons.developer_board_rounded;
      case 'ESP32_CAM': case 'CAMERA': return Icons.videocam_rounded;
      case 'MOTION_SENSOR': return Icons.sensors_rounded;
      case 'LIGHT_SENSOR': return Icons.wb_twilight_rounded;
      case 'SMART_LIGHT': return Icons.lightbulb_rounded;
      default: return Icons.device_hub_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'ESP32': return AppTheme.accentBlue;
      case 'ESP32_CAM': case 'CAMERA': return AppTheme.accentCyan;
      case 'MOTION_SENSOR': return AppTheme.statusWarning;
      case 'LIGHT_SENSOR': return Colors.amber;
      case 'SMART_LIGHT': return Colors.orangeAccent;
      default: return AppTheme.textMuted;
    }
  }
}
