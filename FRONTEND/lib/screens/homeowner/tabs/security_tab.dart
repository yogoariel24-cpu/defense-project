import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../services/api_service.dart';
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

    return RefreshIndicator(
      onRefresh: houseProvider.fetchSecurityEvents,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Live AI Threat Intake Trigger
            GlassCard(
              borderColor: AppTheme.accentCyan.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: AppTheme.accentCyan, size: 22),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Vision & Intrusion Radar', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Processes motion, face match & threat matrix live', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () async {
                      // Trigger real backend telemetry ingestion
                      final api = Provider.of<ApiService>(context, listen: false);
                      await api.sendSecurityTelemetry({
                        'event_type': 'MOTION_DETECTED',
                        'has_person': true,
                        'person_confidence': 0.96,
                        'has_face': true,
                        'face_confidence': 0.91,
                      });
                      await houseProvider.fetchSecurityEvents();
                    },
                    child: const Text('Test Trigger', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Event Feed Header
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
            Row(
              children: [
                _aiChip('Person: ${(event.aiAnalysis!.personConfidence * 100).toStringAsFixed(0)}%', AppTheme.accentCyan),
                const SizedBox(width: 8),
                _aiChip('Face: ${event.aiAnalysis!.faceRecognitionResult}', AppTheme.accentBlue),
                const SizedBox(width: 8),
                _aiChip('Risk: ${event.aiAnalysis!.riskScore.toStringAsFixed(0)}%', threatColor),
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
