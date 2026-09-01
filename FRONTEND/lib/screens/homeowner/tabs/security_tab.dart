import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';
import '../../../models/security_event_model.dart';
import 'package:intl/intl.dart';

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final events = houseProvider.securityEvents;
    final isArmed = houseProvider.house.isArmed;

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

            // Security Event Audit Log Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Security Event Audit Log',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${events.length} events logged',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

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
                itemBuilder: (ctx, i) => _buildEventCard(events[i]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(SecurityEventModel event) {
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
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
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
            DateFormat('MMM d, yyyy • HH:mm:ss').format(event.createdAt),
            style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _aiChip(String label, Color color) {
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
