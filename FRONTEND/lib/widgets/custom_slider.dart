import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomBrightnessSlider extends StatelessWidget {
  final int value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  const CustomBrightnessSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.wb_sunny_rounded, color: AppTheme.accentCyan, size: 18),
                SizedBox(width: 8),
                Text(
                  'Brightness Level',
                  style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            Text(
              '$value%',
              style: const TextStyle(
                color: AppTheme.accentCyan,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.accentCyan,
            inactiveTrackColor: AppTheme.primarySurface,
            thumbColor: Colors.white,
            overlayColor: AppTheme.accentCyan.withOpacity(0.2),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }
}
