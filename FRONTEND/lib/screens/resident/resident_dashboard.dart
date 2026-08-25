import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../widgets/emergency_dialog.dart';
import '../../widgets/custom_slider.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser!;

    return ChangeNotifierProvider(
      create: (_) => HouseProvider(auth.apiService),
      child: Consumer<HouseProvider>(
        builder: (ctx, houseProvider, _) {
          final house = houseProvider.house;
          final events = houseProvider.securityEvents;

          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppTheme.accentBlue.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
                    ),
                    child: Center(
                      child: Text(
                        user.firstName[0],
                        style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: const TextStyle(color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('Resident • ${user.houseId}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted), onPressed: auth.logout),
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                // Home Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Emergency Trigger
                      GlassCard(
                        borderColor: AppTheme.statusDanger.withOpacity(0.5),
                        backgroundColor: AppTheme.statusDanger.withOpacity(0.08),
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(color: AppTheme.statusDanger, shape: BoxShape.circle),
                              child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EMERGENCY PANIC', style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w900, fontSize: 14)),
                                  Text('Alert all house members & authorities', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
                                  onConfirm: () => houseProvider.triggerEmergency(notes: 'Triggered by Resident ${user.fullName}'),
                                );
                              },
                              child: const Text('TRIGGER', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // House Status
                      GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('House Status', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _statusTile(
                                    'Security',
                                    house.securityStatus.replaceAll('_', ' '),
                                    Icons.shield_rounded,
                                    house.isArmed ? AppTheme.accentCyan : AppTheme.statusSafe,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _statusTile(
                                    'Lighting',
                                    '${house.globalBrightness}% • ${house.lightMode}',
                                    Icons.lightbulb_rounded,
                                    AppTheme.accentCyan,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Recent Events
                      const Text('Recent Security Events', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (events.isEmpty)
                        const GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('No recent events.', style: TextStyle(color: AppTheme.textMuted))),
                          ),
                        )
                      else
                        ...events.take(5).map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  e.aiAnalysis?.threatLevel == 'CONFIRMED_THREAT' ? Icons.warning_rounded : Icons.info_outline_rounded,
                                  color: e.aiAnalysis?.threatLevel == 'CONFIRMED_THREAT' ? AppTheme.statusDanger : AppTheme.accentCyan,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.eventType.replaceAll('_', ' '), style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600, fontSize: 13)),
                                      if (e.description != null)
                                        Text(e.description!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                StatBadge(
                                  label: e.status,
                                  color: e.status == 'CONFIRMED_THREAT' ? AppTheme.statusDanger : AppTheme.statusSafe,
                                ),
                              ],
                            ),
                          ),
                        )),
                    ],
                  ),
                ),

                // Lighting Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Lighting Control', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 16),
                            CustomBrightnessSlider(
                              value: house.globalBrightness,
                              onChanged: (val) => houseProvider.setBrightness(val.round()),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.auto_mode_rounded, size: 16),
                                    label: const Text('Auto (LDR)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: house.lightMode == 'AUTO' ? AppTheme.accentBlue : AppTheme.primarySurface,
                                    ),
                                    onPressed: () => houseProvider.setLightMode('AUTO'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.tune_rounded, size: 16),
                                    label: const Text('Manual'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: house.lightMode == 'MANUAL' ? AppTheme.accentBlue : AppTheme.primarySurface,
                                    ),
                                    onPressed: () => houseProvider.setLightMode('MANUAL'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryCard,
                border: Border(top: BorderSide(color: AppTheme.accentBlue.withOpacity(0.2), width: 1)),
              ),
              child: BottomNavigationBar(
                backgroundColor: Colors.transparent,
                selectedItemColor: AppTheme.accentCyan,
                unselectedItemColor: AppTheme.textDim,
                currentIndex: _selectedIndex,
                onTap: (i) => setState(() => _selectedIndex = i),
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
                  BottomNavigationBarItem(icon: Icon(Icons.lightbulb_rounded), label: 'Lighting'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
