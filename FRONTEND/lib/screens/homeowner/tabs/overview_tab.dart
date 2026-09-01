import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';
import '../../../widgets/emergency_dialog.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final house = houseProvider.house;

    Color statusColor = AppTheme.statusSafe;
    String statusText = 'SYSTEM DISARMED';
    IconData statusIcon = Icons.shield_outlined;

    if (house.securityStatus == 'ARMED_AWAY') {
      statusColor = AppTheme.accentCyan;
      statusText = 'ARMED (AWAY)';
      statusIcon = Icons.security_rounded;
    } else if (house.securityStatus == 'ARMED_HOME') {
      statusColor = AppTheme.accentBlue;
      statusText = 'ARMED (HOME)';
      statusIcon = Icons.home_filled;
    } else if (house.isAlarmTriggered) {
      statusColor = AppTheme.statusDanger;
      statusText = '🚨 CRITICAL ALARM ACTIVE';
      statusIcon = Icons.warning_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Emergency Button Banner
          GlassCard(
            backgroundColor: AppTheme.statusDanger.withOpacity(0.12),
            borderColor: AppTheme.statusDanger.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppTheme.statusDanger, shape: BoxShape.circle),
                  child: const Icon(Icons.touch_app_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EMERGENCY PANIC TRIGGER',
                        style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                      ),
                      Text(
                        'Dispatch police & security with one tap',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.statusDanger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    EmergencyDialog.show(
                      context,
                      onConfirm: () => houseProvider.triggerEmergency(notes: 'Triggered from Homeowner Overview Tab'),
                    );
                  },
                  child: const Text('TRIGGER', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Security Status Hub
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(statusIcon, color: statusColor, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          house.name,
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    StatBadge(label: statusText, color: statusColor),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${house.address} • GPS: ${house.latitude.toStringAsFixed(4)}, ${house.longitude.toStringAsFixed(4)} • Police: ${house.emergencyContactPolice}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                const Divider(height: 32, color: Colors.white10),

                // Arm / Disarm Mode Selector
                const Text(
                  'Security Mode Selection',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeButton(
                        context,
                        label: 'Disarm',
                        icon: Icons.lock_open_rounded,
                        isSelected: house.securityStatus == 'DISARMED',
                        activeColor: AppTheme.statusSafe,
                        onTap: () => houseProvider.setSecurityState('DISARMED'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        context,
                        label: 'Arm Home',
                        icon: Icons.night_shelter_rounded,
                        isSelected: house.securityStatus == 'ARMED_HOME',
                        activeColor: AppTheme.accentBlue,
                        onTap: () => houseProvider.setSecurityState('ARMED_HOME'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildModeButton(
                        context,
                        label: 'Arm Away',
                        icon: Icons.shield_rounded,
                        isSelected: house.securityStatus == 'ARMED_AWAY',
                        activeColor: AppTheme.accentCyan,
                        onTap: () => houseProvider.setSecurityState('ARMED_AWAY'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Quick Telemetry Overview Cards
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppTheme.accentCyan, size: 18),
                          SizedBox(width: 6),
                          Text('LIGHTING', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${house.globalBrightness}%', style: const TextStyle(color: AppTheme.textLight, fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('Mode: ${house.lightMode}', style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.devices_rounded, color: AppTheme.statusSafe, size: 18),
                          SizedBox(width: 6),
                          Text('DEVICES', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${houseProvider.devices.length} Online', style: const TextStyle(color: AppTheme.textLight, fontSize: 22, fontWeight: FontWeight.w800)),
                      const Text('ESP32 Core Active', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? activeColor.withOpacity(0.18) : AppTheme.primarySurface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white10,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? activeColor : AppTheme.textMuted, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
