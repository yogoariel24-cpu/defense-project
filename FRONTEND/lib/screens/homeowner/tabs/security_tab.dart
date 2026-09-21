import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';
import '../../../widgets/emergency_dialog.dart';
import '../../../models/security_event_model.dart';
import '../room_management_screen.dart';
import '../rfid_management_screen.dart';
import '../access_history_screen.dart';

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  int _selectedSection = 0; // 0 = Dashboard Overview, 1 = Detections Feed, 2 = Security Events

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final events = houseProvider.securityEvents;
    final detections = houseProvider.detectionEvents;
    final accessLogs = houseProvider.accessHistory;
    final isArmed = houseProvider.house.isArmed;
    final deviceSummary = houseProvider.deviceSummary;
    final threatStatus = houseProvider.threatStatus;
    final activeThreat = houseProvider.activeThreat;

    return RefreshIndicator(
      onRefresh: () async {
        await houseProvider.fetchSecurityStatus();
        await houseProvider.fetchDetectionEvents();
        await houseProvider.fetchAccessHistory();
        await houseProvider.fetchDevices();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. High-Priority Verified Threat Banner (When threat reaches VERIFIED_THREAT)
            if (threatStatus == 'VERIFIED_THREAT' || activeThreat != null) ...[
              GlassCard(
                borderColor: AppTheme.statusDanger,
                backgroundColor: AppTheme.statusDanger.withOpacity(0.14),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppTheme.statusDanger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚨 VERIFIED SECURITY THREAT',
                                style: TextStyle(
                                  color: AppTheme.statusDanger,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Automated security response active — emergency dispatched',
                                style: TextStyle(color: AppTheme.textLight, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const StatBadge(
                          label: 'VERIFIED THREAT',
                          color: AppTheme.statusDanger,
                          icon: Icons.shield_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activeThreat?.description ?? 'Intruder breach detected while security was armed.',
                      style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.statusDanger.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.statusDanger.withOpacity(0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.statusDanger),
                              SizedBox(width: 6),
                              Text(
                                'Auto-Response Dispatched',
                                style: TextStyle(color: AppTheme.statusDanger, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (activeThreat != null)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.statusSafe,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: () => houseProvider.updateSecurityEventStatus(activeThreat.id, 'RESOLVED'),
                            child: const Text('Mark Resolved', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 2. Security Status & Arm / Disarm Controls
            GlassCard(
              padding: const EdgeInsets.all(18),
              borderColor: isArmed ? AppTheme.accentCyan.withOpacity(0.5) : AppTheme.statusSafe.withOpacity(0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isArmed ? AppTheme.accentCyan : AppTheme.statusSafe).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isArmed ? Icons.shield_rounded : Icons.shield_outlined,
                          color: isArmed ? AppTheme.accentCyan : AppTheme.statusSafe,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Security Status: ${houseProvider.house.securityStatus.replaceAll('_', ' ')}',
                              style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isArmed ? 'Active perimeter & biometric monitoring' : 'Standby mode — access logging active',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatBadge(
                        label: isArmed ? 'ARMED' : 'DISARMED',
                        color: isArmed ? AppTheme.accentCyan : AppTheme.statusSafe,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _armButton(
                          label: 'DISARM',
                          icon: Icons.lock_open_rounded,
                          isActive: !isArmed,
                          activeColor: AppTheme.statusSafe,
                          onPressed: () => houseProvider.setSecurityState('DISARMED'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _armButton(
                          label: 'ARM HOME',
                          icon: Icons.home_rounded,
                          isActive: houseProvider.house.securityStatus == 'ARMED_HOME',
                          activeColor: AppTheme.accentOrange,
                          onPressed: () => houseProvider.setSecurityState('ARMED_HOME'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _armButton(
                          label: 'ARM AWAY',
                          icon: Icons.shield_rounded,
                          isActive: houseProvider.house.securityStatus == 'ARMED_AWAY',
                          activeColor: AppTheme.accentCyan,
                          onPressed: () => houseProvider.setSecurityState('ARMED_AWAY'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Hardware Device Status Summary
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.devices_rounded, size: 20, color: AppTheme.accentCyan),
                      const SizedBox(width: 8),
                      const Text('IoT Device Status', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Text(
                        '${deviceSummary['online'] ?? houseProvider.devices.where((d) => d.status == 'ONLINE').length} Online / ${deviceSummary['total'] ?? houseProvider.devices.length} Total',
                        style: const TextStyle(color: AppTheme.statusSafe, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _deviceStatusTile('Cameras', deviceSummary['byType']?['CAMERA']?.toString() ?? '1', Icons.videocam_rounded),
                      const SizedBox(width: 8),
                      _deviceStatusTile('RFID Readers', deviceSummary['byType']?['RFID_READER']?.toString() ?? '1', Icons.nfc_rounded),
                      const SizedBox(width: 8),
                      _deviceStatusTile('Door Locks', deviceSummary['byType']?['DOOR_LOCK']?.toString() ?? '1', Icons.lock_rounded),
                      const SizedBox(width: 8),
                      _deviceStatusTile('Sensors', deviceSummary['byType']?['PRESENCE_SENSOR']?.toString() ?? '2', Icons.sensors_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Quick Access Hub (Rooms, RFID Cards, Access Log)
            Row(
              children: [
                Expanded(
                  child: _quickNavCard(
                    context: context,
                    icon: Icons.meeting_room_rounded,
                    label: 'Rooms',
                    subtitle: '${houseProvider.rooms.length} configured',
                    color: AppTheme.accentCyan,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagementScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickNavCard(
                    context: context,
                    icon: Icons.credit_card_rounded,
                    label: 'RFID Cards',
                    subtitle: '${houseProvider.rfidCards.length} registered',
                    color: AppTheme.accentOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RfidManagementScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickNavCard(
                    context: context,
                    icon: Icons.history_rounded,
                    label: 'Access Log',
                    subtitle: '${accessLogs.length} attempts',
                    color: AppTheme.statusSafe,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessHistoryScreen())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Section Switcher Tabs
            Row(
              children: [
                Expanded(
                  child: _sectionTab('OVERVIEW', 0, Icons.dashboard_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _sectionTab('DETECTIONS (${detections.length})', 1, Icons.sensors_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _sectionTab('SECURITY (${events.length})', 2, Icons.shield_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab 0: Overview (Recent RFID / Face Access + Recent Events)
            if (_selectedSection == 0) ...[
              // Recent Access Feed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RECENT RFID & FACE ACCESS', style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessHistoryScreen())),
                    child: const Text('View All', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (accessLogs.isEmpty)
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No access attempts recorded yet.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: accessLogs.length > 5 ? 5 : accessLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final log = accessLogs[idx];
                    final isGranted = log.isGranted;
                    return GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      borderColor: (isGranted ? AppTheme.statusSafe : AppTheme.statusDanger).withOpacity(0.3),
                      child: Row(
                        children: [
                          Icon(
                            log.accessMethod == 'FACE_EMBEDDING' ? Icons.face_rounded : Icons.credit_card_rounded,
                            color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(log.residentName, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('${log.roomName} • ${DateFormat('HH:mm:ss').format(log.timestamp)}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                              ],
                            ),
                          ),
                          StatBadge(
                            label: log.status,
                            color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],

            // Tab 1: Detections Feed (Crucial distinction: DETECTED != VERIFIED_THREAT)
            if (_selectedSection == 1) ...[
              if (detections.isEmpty)
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.sensors_rounded, color: AppTheme.accentCyan, size: 40),
                          SizedBox(height: 12),
                          Text('Sensor & Telemetry Ingestion Active', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('Presence detections, motion readings, and sensor telemetry log here.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: detections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final d = detections[idx];
                    final isVerifiedThreat = d.isVerifiedThreat || d.status == 'VERIFIED_THREAT';
                    final color = isVerifiedThreat ? AppTheme.statusDanger : AppTheme.accentCyan;

                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: color.withOpacity(0.35),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                            child: Icon(
                              isVerifiedThreat ? Icons.warning_amber_rounded : Icons.motion_photos_on_rounded,
                              color: color,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      (d.className ?? d.objectType).toUpperCase(),
                                      style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const Spacer(),
                                    StatBadge(
                                      label: isVerifiedThreat ? 'VERIFIED THREAT' : 'DETECTED',
                                      color: color,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Confidence: ${(d.confidence * 100).toStringAsFixed(0)}% • ${DateFormat('MM/dd HH:mm:ss').format(d.timestamp)}',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],

            // Tab 2: Security Events Log
            if (_selectedSection == 2) ...[
              if (events.isEmpty)
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No security events recorded.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final e = events[idx];
                    final isCritical = e.severity == 'CRITICAL' || e.status == 'CONFIRMED_THREAT';
                    final color = isCritical ? AppTheme.statusDanger : AppTheme.accentCyan;

                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      borderColor: color.withOpacity(0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_rounded, color: color, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.eventType.replaceAll('_', ' '),
                                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              StatBadge(label: e.status, color: color),
                            ],
                          ),
                          if (e.description != null && e.description!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(e.description!, style: const TextStyle(color: AppTheme.textLight, fontSize: 12)),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('EEE, MMM d • HH:mm:ss').format(e.createdAt),
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _armButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? activeColor : AppTheme.primarySurface,
        foregroundColor: isActive ? Colors.black : AppTheme.textLight,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
    );
  }

  Widget _deviceStatusTile(String label, String count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppTheme.accentCyan),
            const SizedBox(height: 4),
            Text(count, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _quickNavCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      onTap: onTap,
      borderColor: color.withOpacity(0.3),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _sectionTab(String label, int index, IconData icon) {
    final isSelected = _selectedSection == index;
    return InkWell(
      onTap: () => setState(() => _selectedSection = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentCyan.withOpacity(0.18) : AppTheme.primaryCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.accentCyan : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
