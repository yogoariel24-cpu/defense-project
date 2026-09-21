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

import 'room_management_screen.dart';
import 'rfid_management_screen.dart';
import 'access_history_screen.dart';

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

    // If payment is not yet validated by the admin, gate access behind PaymentScreen
    if (!user.isPaymentApproved && !_forceUnlocked) {
      return PaymentScreen(
        onPaymentApproved: () {
          setState(() => _forceUnlocked = true);
        },
      );
    }

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
              Text(user.houseName ?? user.houseId ?? '', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune_rounded, color: AppTheme.accentCyan),
              tooltip: 'Access & Room Controls',
              color: AppTheme.primaryCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'rooms') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagementScreen()));
                } else if (val == 'rfid') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RfidManagementScreen()));
                } else if (val == 'history') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessHistoryScreen()));
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'rooms',
                  child: Row(
                    children: [
                      Icon(Icons.meeting_room_rounded, color: AppTheme.accentCyan, size: 18),
                      SizedBox(width: 10),
                      Text('Room Management', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'rfid',
                  child: Row(
                    children: [
                      Icon(Icons.credit_card_rounded, color: AppTheme.accentOrange, size: 18),
                      SizedBox(width: 10),
                      Text('RFID Keycards', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: AppTheme.statusSafe, size: 18),
                      SizedBox(width: 10),
                      Text('Access History Audit', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
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
      );
  }
}

