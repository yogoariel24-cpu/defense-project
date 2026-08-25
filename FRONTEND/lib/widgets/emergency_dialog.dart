import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EmergencyDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const EmergencyDialog({super.key, required this.onConfirm});

  static Future<bool?> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => EmergencyDialog(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.primaryCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppTheme.statusDanger, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.statusDanger.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.statusDanger,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'CONFIRM EMERGENCY DISPATCH',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.statusDanger,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Triggering this emergency alert will immediately notify local police services, on-call security agents, and broadcast critical sirens to all house residents.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textLight,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.statusDanger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context, true);
                      onConfirm();
                    },
                    child: const Text('DISPATCH NOW'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
