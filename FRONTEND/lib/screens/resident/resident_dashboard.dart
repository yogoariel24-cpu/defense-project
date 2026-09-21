import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../widgets/emergency_dialog.dart';
import '../../widgets/custom_slider.dart';
import 'package:intl/intl.dart';

class ResidentDashboard extends StatefulWidget {
  const ResidentDashboard({super.key});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<HouseProvider>(context, listen: false).refreshAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final permissions = user.permissions ?? {};
    final canViewCameras = permissions['can_view_cameras'] == true;
    final canControlLights = permissions['can_control_lights'] ?? true;
    final canArmSecurity = permissions['can_arm_security'] == true;

    return Consumer<HouseProvider>(
      builder: (ctx, houseProvider, _) {
          final house = houseProvider.house;
          final events = houseProvider.securityEvents;
          final snapshotEvents = events.where((e) => e.imageUrl != null && e.imageUrl!.isNotEmpty).toList();

          return Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.5), width: 1.5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: AppTheme.accentCyan, size: 20),
                    ),
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(color: AppTheme.textLight, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Resident • ${user.houseId}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
              actions: [
                IconButton(icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted), onPressed: auth.logout),
              ],
            ),
            body: IndexedStack(
              index: _selectedIndex,
              children: [
                // 0. Home Tab
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
                                  Text('Alert police & house residents with live GPS', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
                      // Recent Events Preview
                      const Text('Recent Security Audit', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (events.isEmpty)
                        const GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: Text('No recent events.', style: TextStyle(color: AppTheme.textMuted))),
                          ),
                        )
                      else
                        ...events.take(4).map((e) => Padding(
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

                // 1. Lighting Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!canControlLights)
                        const GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.lock_outline_rounded, color: AppTheme.statusWarning, size: 36),
                                  SizedBox(height: 10),
                                  Text('Lighting Control Restricted', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 4),
                                  Text('The homeowner has disabled smart lighting controls for your resident profile.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
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

                // 2. Security & Camera Images Tab (Permission Protected)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!canViewCameras)
                        const GlassCard(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.no_photography_outlined, color: AppTheme.statusWarning, size: 40),
                                  SizedBox(height: 12),
                                  Text('Security Images Restricted', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w700)),
                                  SizedBox(height: 6),
                                  Text(
                                    'You do not have authorization from the homeowner to view security camera snapshots and perimeter logs.',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Camera Snapshots Gallery', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                            Text('${snapshotEvents.length} snapshots', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        if (snapshotEvents.isEmpty)
                          const GlassCard(
                            child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.camera_alt_outlined, color: AppTheme.textMuted, size: 36),
                                    SizedBox(height: 10),
                                    Text('No Images Captured Yet', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                                    Text('Snapshots will appear when security sensors trigger.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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

                              return GlassCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
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
                              );
                            },
                          ),
                      ],
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
                  BottomNavigationBarItem(icon: Icon(Icons.security_rounded), label: 'Security & Images'),
                ],
              ),
            ),
          );
        },
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
