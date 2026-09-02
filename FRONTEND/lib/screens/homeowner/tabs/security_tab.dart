import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';
import '../../../models/security_event_model.dart';
import 'package:intl/intl.dart';

class SecurityTab extends StatefulWidget {
  const SecurityTab({super.key});

  @override
  State<SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<SecurityTab> {
  int _viewMode = 0; // 0 = All Security Events, 1 = Snapshots Gallery Only

  void _showImagePreview(BuildContext context, String imageUrl, String title, String timestamp, SecurityEventModel event) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.primaryCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppTheme.primarySurface,
                  child: const Center(child: Icon(Icons.broken_image_rounded, size: 48, color: AppTheme.textMuted)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(timestamp, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  if (event.aiAnalysis != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _aiChip('Face: ${event.aiAnalysis!.faceRecognitionResult}', event.aiAnalysis!.faceRecognitionResult == 'UNKNOWN' ? AppTheme.statusDanger : AppTheme.statusSafe),
                        if (event.aiAnalysis!.personDetected)
                          _aiChip('Human: ${(event.aiAnalysis!.personConfidence * 100).toStringAsFixed(0)}%', AppTheme.accentCyan),
                        _aiChip('Risk: ${event.aiAnalysis!.riskScore.toStringAsFixed(0)}%', AppTheme.statusWarning),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final events = houseProvider.securityEvents;
    final isArmed = houseProvider.house.isArmed;

    final snapshotEvents = events.where((e) => e.imageUrl != null && e.imageUrl!.isNotEmpty).toList();

    return RefreshIndicator(
      onRefresh: houseProvider.fetchSecurityEvents,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Perimeter Status Banner
            GlassCard(
              borderColor: isArmed ? AppTheme.accentCyan.withOpacity(0.4) : AppTheme.statusSafe.withOpacity(0.4),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isArmed ? AppTheme.accentCyan : AppTheme.statusSafe).withOpacity(0.12),
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
                          'Perimeter Security: ${houseProvider.house.securityStatus.replaceAll('_', ' ')}',
                          style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArmed ? 'AI Threat Detection and Motion Sensors Active' : 'System standby. Armed sensors ready.',
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
            ),
            const SizedBox(height: 20),

            // View Selector Tabs (Events Log vs Security Snapshots Gallery)
            Row(
              children: [
                Expanded(
                  child: _buildViewTab('AUDIT LOG (${events.length})', 0, Icons.list_alt_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildViewTab('SECURITY IMAGES (${snapshotEvents.length})', 1, Icons.photo_library_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_viewMode == 1) ...[
              // Snapshots Gallery Grid
              if (snapshotEvents.isEmpty)
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppTheme.textMuted, size: 40),
                          SizedBox(height: 12),
                          Text('No Security Images Captured', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                          Text('AI radar captures snapshots when motion or unrecognized faces appear.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: snapshotEvents.length,
                  itemBuilder: (ctx, i) {
                    final e = snapshotEvents[i];
                    final timeStr = DateFormat('MMM d, HH:mm').format(e.createdAt);

                    return GestureDetector(
                      onTap: () => _showImagePreview(context, e.imageUrl!, e.eventType.replaceAll('_', ' '), timeStr, e),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                    child: Image.network(
                                      e.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppTheme.primarySurface,
                                        child: const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
                                      ),
                                    ),
                                  ),
                                  if (e.aiAnalysis?.faceRecognitionResult == 'UNKNOWN')
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppTheme.statusDanger, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('UNKNOWN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.eventType.replaceAll('_', ' '),
                                    style: const TextStyle(color: AppTheme.textLight, fontSize: 11, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(timeStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // Events Audit Log
              if (events.isEmpty)
                const GlassCard(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppTheme.statusSafe, size: 40),
                          SizedBox(height: 12),
                          Text('Perimeter Secure', style: TextStyle(color: AppTheme.statusSafe, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('No security infractions or anomalies recorded.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _buildEventCard(context, events[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(String label, int index, IconData icon) {
    final isSelected = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? AppTheme.accentCyan.withOpacity(0.5) : Colors.white10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, SecurityEventModel event) {
    Color threatColor = AppTheme.statusSafe;
    IconData icon = Icons.check_circle_outline;
    String threatLabel = 'NORMAL';

    if (event.aiAnalysis?.threatLevel == 'CONFIRMED_THREAT' || event.status == 'CONFIRMED_THREAT') {
      threatColor = AppTheme.statusDanger;
      icon = Icons.warning_rounded;
      threatLabel = 'CONFIRMED THREAT';
    } else if (event.aiAnalysis?.threatLevel == 'SUSPICIOUS' || event.status == 'INVESTIGATING') {
      threatColor = AppTheme.statusWarning;
      icon = Icons.query_stats_rounded;
      threatLabel = 'SUSPICIOUS';
    } else if (event.eventType == 'MANUAL_EMERGENCY') {
      threatColor = AppTheme.statusDanger;
      icon = Icons.emergency_rounded;
      threatLabel = 'EMERGENCY';
    }

    final timeStr = DateFormat('MMM d, yyyy • HH:mm:ss').format(event.createdAt);

    return GlassCard(
      borderColor: threatColor.withOpacity(0.4),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: threatColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  event.eventType.replaceAll('_', ' '),
                  style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              StatBadge(label: threatLabel, color: threatColor),
            ],
          ),
          const SizedBox(height: 10),
          if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => _showImagePreview(context, event.imageUrl!, event.eventType.replaceAll('_', ' '), timeStr, event),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Image.network(
                      event.imageUrl!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(child: Icon(Icons.camera_alt_outlined, color: AppTheme.textDim)),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Inspect', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (event.imageUrl != null && event.imageUrl!.isNotEmpty) const SizedBox(height: 10),
          if (event.description != null)
            Text(event.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4)),
          if (event.aiAnalysis != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _aiChip('Face: ${event.aiAnalysis!.faceRecognitionResult == 'UNKNOWN' ? '🚨 UNRECOGNIZED' : event.aiAnalysis!.faceRecognitionResult}', event.aiAnalysis!.faceRecognitionResult == 'UNKNOWN' ? AppTheme.statusDanger : AppTheme.statusSafe),
                if (event.aiAnalysis!.personDetected)
                  _aiChip('Human: ${(event.aiAnalysis!.personConfidence * 100).toStringAsFixed(0)}%', AppTheme.accentCyan),
                _aiChip('Risk Score: ${event.aiAnalysis!.riskScore.toStringAsFixed(0)}%', threatColor),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static Widget _aiChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}
