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
                        'Emails police live Google Maps location & calls dispatch',
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

          // Access Control & Security Metric Cards (Section 23)
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.credit_card_rounded, color: AppTheme.accentOrange, size: 18),
                          SizedBox(width: 6),
                          Text('ACCESS CARDS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${houseProvider.rfidCards.where((c) => c.isActive).length} Active', style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${houseProvider.rfidCards.length} Total Cards', style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
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
                          Icon(Icons.videocam_rounded, color: AppTheme.accentCyan, size: 18),
                          SizedBox(width: 6),
                          Text('AI CAMERAS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${houseProvider.cameras.where((c) => c.isOnline).length} Streaming', style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${houseProvider.cameras.length} Provisioned', style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.meeting_room_rounded, color: AppTheme.accentCyan, size: 18),
                          SizedBox(width: 6),
                          Text('ROOMS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${houseProvider.rooms.length} Rooms', style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.w800)),
                      const Text('Secured Boundaries', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
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
                          Text('HARDWARE', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${houseProvider.devices.length} Online', style: const TextStyle(color: AppTheme.textLight, fontSize: 20, fontWeight: FontWeight.w800)),
                      const Text('ESP32 Access Controller', style: TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Access & Security Activity Stream
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Access & Security Activity', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.bold)),
                    Icon(Icons.history_rounded, color: AppTheme.accentCyan, size: 18),
                  ],
                ),
                const SizedBox(height: 12),
                if (houseProvider.accessHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text('No access activity recorded yet.', style: TextStyle(color: AppTheme.textDim, fontSize: 12)),
                    ),
                  )
                else
                  ...houseProvider.accessHistory.take(4).map((log) {
                    final isGranted = log.isGranted;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                      child: Row(
                        children: [
                          Icon(
                            isGranted ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                            color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  log.residentName ?? 'Unregistered RFID / Unknown Face',
                                  style: const TextStyle(color: AppTheme.textLight, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${log.accessMethod} • ${log.roomName ?? 'Main Entrance'}',
                                  style: const TextStyle(color: AppTheme.textDim, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            isGranted ? 'GRANTED' : 'DENIED',
                            style: TextStyle(
                              color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
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
