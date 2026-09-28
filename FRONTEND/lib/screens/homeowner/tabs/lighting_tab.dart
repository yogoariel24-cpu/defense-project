// DEPRECATED: Smart lighting scope has been removed.
// Replaced by CameraManagementScreen and Access Control screens.
import 'package:flutter/material.dart';
import '../camera_management_screen.dart';

class LightingTab extends StatelessWidget {
  const LightingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const CameraManagementScreen();
  }
}
