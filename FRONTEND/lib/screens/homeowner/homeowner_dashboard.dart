import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import 'payment_screen.dart';
import 'tabs/overview_tab.dart';
import 'tabs/lighting_tab.dart';
import 'tabs/security_tab.dart';
import 'tabs/devices_tab.dart';
import 'tabs/residents_tab.dart';

class HomeownerDashboard extends StatefulWidget {
  const HomeownerDashboard({super.key});

  @override
  State<HomeownerDashboard> createState() => _HomeownerDashboardState();
}

class _HomeownerDashboardState extends State<HomeownerDashboard> {
  int _selectedIndex = 0;
  bool _forceUnlocked = false;

  final List<({String label, IconData icon, IconData activeIcon})> _tabs = [
    (label: 'Overview', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded),
    (label: 'Security', icon: Icons.shield_outlined, activeIcon: Icons.shield_rounded),
    (label: 'Lighting', icon: Icons.lightbulb_outline_rounded, activeIcon: Icons.lightbulb_rounded),
    (label: 'Devices', icon: Icons.devices_outlined, activeIcon: Icons.devices_rounded),
    (label: 'Residents', icon: Icons.group_outlined, activeIcon: Icons.group_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser!;

    // If payment is not yet validated by the admin, gate access behind PaymentScreen
    if (!user.isPaymentApproved && !_forceUnlocked) {
      return PaymentScreen(
        onPaymentApproved: () {
          setState(() => _forceUnlocked = true);
        },
      );
    }

    return ChangeNotifierProvider(
      create: (_) => HouseProvider(auth.apiService),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.accentBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    user.firstName.isNotEmpty ? user.firstName[0] : 'H',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text(user.houseName ?? user.houseId ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textLight),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notification center: All systems operational.')),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted),
              onPressed: auth.logout,
            ),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: const [
            OverviewTab(),
            SecurityTab(),
            LightingTab(),
            DevicesTab(),
            ResidentsTab(),
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
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 10),
            currentIndex: _selectedIndex,
            onTap: (i) => setState(() => _selectedIndex = i),
            items: _tabs
                .map((t) => BottomNavigationBarItem(
                      icon: Icon(_selectedIndex == _tabs.indexOf(t) ? t.activeIcon : t.icon),
                      label: t.label,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}
