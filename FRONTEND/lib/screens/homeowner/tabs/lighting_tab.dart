import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';
import '../../../widgets/custom_slider.dart';

class LightingTab extends StatelessWidget {
  const LightingTab({super.key});

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final house = houseProvider.house;
    final isAuto = house.lightMode == 'AUTO';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mode Toggle Header Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Lighting Engine',
                          style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'LDR Sensor Auto-Dimming & PWM',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    StatBadge(
                      label: isAuto ? 'AUTOMATIC (LDR)' : 'MANUAL OVERRIDE',
                      color: isAuto ? AppTheme.accentCyan : AppTheme.statusWarning,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Auto / Manual Switch
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => houseProvider.setLightMode('AUTO'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isAuto ? AppTheme.accentBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_mode_rounded, size: 16, color: isAuto ? Colors.white : AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Text('Automatic (LDR)', style: TextStyle(color: isAuto ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => houseProvider.setLightMode('MANUAL'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !isAuto ? AppTheme.accentBlue : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune_rounded, size: 16, color: !isAuto ? Colors.white : AppTheme.textMuted),
                                const SizedBox(width: 6),
                                Text('Manual Control', style: TextStyle(color: !isAuto ? Colors.white : AppTheme.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                CustomBrightnessSlider(
                  value: house.globalBrightness,
                  onChanged: (val) {
                    houseProvider.setBrightness(val.round());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Ambient Lux Telemetry from LDR
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wb_sunny_outlined, color: AppTheme.accentCyan, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outdoor Ambient Lux Sensor', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14)),
                      SizedBox(height: 2),
                      Text('Target Threshold: 200 Lux • ESP32 ADC Pin 34', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('145.0 Lux', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Dim Level 80%', style: TextStyle(color: AppTheme.statusSafe, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Active Lighting Fixtures',
            style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),

          // Fixtures List
          _buildFixtureCard(
            title: 'Living Room Center Chandelier',
            location: 'Living Room • GPIO 23 Relay',
            brightness: house.globalBrightness,
            isOn: true,
          ),
          const SizedBox(height: 12),
          _buildFixtureCard(
            title: 'Porch Security Floodlight',
            location: 'Front Entrance Porch • GPIO 22 Relay',
            brightness: 100,
            isOn: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFixtureCard({
    required String title,
    required String location,
    required int brightness,
    required bool isOn,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_rounded,
            color: isOn ? AppTheme.accentCyan : AppTheme.textDim,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(location, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '$brightness%',
            style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
