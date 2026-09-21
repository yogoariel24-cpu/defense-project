import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/house_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../models/rfid_card_model.dart';
import '../../models/resident_model.dart';
import '../../models/room_model.dart';

class RfidManagementScreen extends StatefulWidget {
  const RfidManagementScreen({super.key});

  @override
  State<RfidManagementScreen> createState() => _RfidManagementScreenState();
}

class _RfidManagementScreenState extends State<RfidManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<HouseProvider>(context, listen: false);
      provider.fetchRfidCards();
      provider.fetchResidents();
      provider.fetchRooms();
    });
  }

  void _showCardDialog([RfidCardModel? card]) {
    final uidCtrl = TextEditingController(text: card?.cardUid ?? '');
    final labelCtrl = TextEditingController(text: card?.label ?? 'Master Keycard');
    String? selectedResidentId = card?.residentId;
    String selectedStatus = card?.status ?? 'ACTIVE';

    final residents = Provider.of<HouseProvider>(context, listen: false).residents;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.primaryCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            card == null ? 'Register New RFID Card' : 'Edit RFID Card',
            style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: uidCtrl,
                  enabled: card == null, // UID is hardware fixed once created
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppTheme.textLight, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'Card / Fob UID',
                    hintText: 'e.g. A1:B2:C3:D4 or 73829104',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: labelCtrl,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Card Label / Description',
                    hintText: 'e.g. Martin Master Keycard, Guest Fob 1',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  value: selectedResidentId,
                  dropdownColor: AppTheme.primaryCard,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(labelText: 'Assigned Resident'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Unassigned (Guest Keycard)', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                    ...residents.map(
                      (r) => DropdownMenuItem<String?>(
                        value: r.id,
                        child: Text(r.fullName),
                      ),
                    ),
                  ],
                  onChanged: (val) => setDlgState(() => selectedResidentId = val),
                ),
                if (card != null) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    dropdownColor: AppTheme.primaryCard,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: const InputDecoration(labelText: 'Card Status'),
                    items: const [
                      DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE — Access Permitted')),
                      DropdownMenuItem(value: 'BLOCKED', child: Text('BLOCKED — Temporarily Suspended')),
                      DropdownMenuItem(value: 'REVOKED', child: Text('REVOKED — Card Lost / Invalid')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedStatus = val);
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
              onPressed: () async {
                final uid = uidCtrl.text.trim().toUpperCase();
                final label = labelCtrl.text.trim();
                if (uid.isEmpty || label.isEmpty) return;

                final provider = Provider.of<HouseProvider>(context, listen: false);
                Navigator.pop(ctx);

                if (card == null) {
                  await provider.registerRfidCard(cardUid: uid, label: label, residentId: selectedResidentId);
                } else {
                  await provider.updateRfidCard(card.id, label: label, residentId: selectedResidentId, status: selectedStatus);
                }
              },
              child: Text(card == null ? 'Register' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RfidCardModel card) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete RFID Card?', style: TextStyle(color: AppTheme.statusDanger)),
        content: Text(
          'Delete card "${card.label}" (${card.cardUid})? This card will immediately stop working at all readers.',
          style: const TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<HouseProvider>(context, listen: false).deleteRfidCard(card.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTestAccessSimulator(RfidCardModel card) {
    final rooms = Provider.of<HouseProvider>(context, listen: false).rooms;
    String? selectedRoomId = rooms.isNotEmpty ? rooms.first.id : null;
    String deviceId = 'RFID_READER_FRONT_01';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.primaryCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.nfc_rounded, color: AppTheme.accentCyan),
              SizedBox(width: 8),
              Text('Test RFID Access Attempt', style: TextStyle(color: AppTheme.textLight, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulate an RFID reader hardware swipe to test backend room permission and resident authorization:',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Text('Card: ${card.label} (${card.cardUid})', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
              Text('Assigned to: ${card.residentName}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 14),
              if (rooms.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  value: selectedRoomId,
                  dropdownColor: AppTheme.primaryCard,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(labelText: 'Target Room Reader'),
                  items: rooms
                      .map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} (${r.isRestricted ? "Restricted" : "Standard"})')))
                      .toList(),
                  onChanged: (val) => setDlgState(() => selectedRoomId = val),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                final apiService = Provider.of<ApiService>(context, listen: false);
                final res = await apiService.testRfidAccess(
                  cardUid: card.cardUid,
                  deviceIdentifier: deviceId,
                  roomId: selectedRoomId,
                );

                if (!mounted) return;
                final bool granted = res['granted'] == true;
                final String reason = res['reason'] ?? res['message'] ?? (granted ? 'Door Unlocked' : 'Denied');

                showDialog(
                  context: context,
                  builder: (rCtx) => AlertDialog(
                    backgroundColor: AppTheme.primaryCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Row(
                      children: [
                        Icon(granted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            color: granted ? AppTheme.statusSafe : AppTheme.statusDanger),
                        const SizedBox(width: 8),
                        Text(granted ? 'ACCESS GRANTED' : 'ACCESS DENIED',
                            style: TextStyle(color: granted ? AppTheme.statusSafe : AppTheme.statusDanger)),
                      ],
                    ),
                    content: Text(
                      granted
                          ? '✅ Backend authorization check passed!\nRoom permissions verified in DB.\nDoor unlock signal emitted.'
                          : '❌ Backend denied access.\nReason: $reason',
                      style: const TextStyle(color: AppTheme.textLight),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(rCtx), child: const Text('OK')),
                    ],
                  ),
                );

                Provider.of<HouseProvider>(context, listen: false).fetchAccessHistory();
                Provider.of<HouseProvider>(context, listen: false).fetchRfidCards();
              },
              child: const Text('Simulate Swipe'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return AppTheme.statusSafe;
      case 'BLOCKED':
        return AppTheme.statusWarning;
      case 'REVOKED':
        return AppTheme.statusDanger;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final cards = houseProvider.rfidCards;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('RFID Keycard Management', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.primaryCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => houseProvider.fetchRfidCards(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Register Card', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCardDialog(),
      ),
      body: RefreshIndicator(
        onRefresh: () => houseProvider.fetchRfidCards(),
        child: cards.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 60),
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.credit_card_off_rounded, size: 56, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No RFID Cards Registered',
                          style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Register RFID keycards or NFC fobs for your residents to enable secure physical entry.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Register First Keycard'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                          onPressed: () => _showCardDialog(),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final card = cards[idx];
                  final statusColor = _getStatusColor(card.status);

                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.nfc_rounded, color: statusColor, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    card.label,
                                    style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'UID: ${card.cardUid}',
                                    style: const TextStyle(color: AppTheme.accentCyan, fontFamily: 'monospace', fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            StatBadge(
                              label: card.status,
                              color: statusColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'Holder: ${card.residentName}',
                              style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
                            ),
                            const Spacer(),
                            if (card.lastUsedAt != null) ...[
                              const Icon(Icons.access_time_rounded, size: 14, color: AppTheme.textMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Used: ${DateFormat('MM/dd HH:mm').format(card.lastUsedAt!)}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.play_arrow_rounded, size: 16),
                              label: const Text('Test Swipe'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                              onPressed: () => _showTestAccessSimulator(card),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textMuted),
                              tooltip: 'Edit Card',
                              onPressed: () => _showCardDialog(card),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.statusDanger),
                              tooltip: 'Delete Card',
                              onPressed: () => _confirmDelete(card),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
