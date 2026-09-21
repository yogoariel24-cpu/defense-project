import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../models/access_history_model.dart';

class AccessHistoryScreen extends StatefulWidget {
  const AccessHistoryScreen({super.key});

  @override
  State<AccessHistoryScreen> createState() => _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends State<AccessHistoryScreen> {
  String _selectedFilter = 'ALL'; // ALL, RFID, FACE_EMBEDDING, GRANTED, DENIED

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HouseProvider>(context, listen: false).fetchAccessHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final allLogs = houseProvider.accessHistory;

    final filteredLogs = allLogs.where((log) {
      if (_selectedFilter == 'RFID') return log.accessMethod == 'RFID';
      if (_selectedFilter == 'FACE_EMBEDDING') return log.accessMethod == 'FACE_EMBEDDING';
      if (_selectedFilter == 'GRANTED') return log.status == 'GRANTED';
      if (_selectedFilter == 'DENIED') return log.status == 'DENIED';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Access History & Audit Log', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.primaryCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => houseProvider.fetchAccessHistory(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.primaryCard.withOpacity(0.5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('ALL', 'All Attempts (${allLogs.length})'),
                  const SizedBox(width: 8),
                  _filterChip('GRANTED', 'Granted'),
                  const SizedBox(width: 8),
                  _filterChip('DENIED', 'Denied'),
                  const SizedBox(width: 8),
                  _filterChip('RFID', 'RFID Keycards'),
                  const SizedBox(width: 8),
                  _filterChip('FACE_EMBEDDING', 'Face Recognition'),
                ],
              ),
            ),
          ),

          // Logs List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => houseProvider.fetchAccessHistory(),
              child: filteredLogs.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 56, color: AppTheme.textMuted.withOpacity(0.5)),
                              const SizedBox(height: 14),
                              const Text(
                                'No Access Logs Found',
                                style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'RFID card swipes and facial recognition access events will appear here in real time.',
                                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredLogs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final log = filteredLogs[idx];
                        final isGranted = log.isGranted;
                        final isFace = log.accessMethod == 'FACE_EMBEDDING';

                        return GlassCard(
                          padding: const EdgeInsets.all(14),
                          borderColor: (isGranted ? AppTheme.statusSafe : AppTheme.statusDanger).withOpacity(0.3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isGranted ? AppTheme.statusSafe : AppTheme.statusDanger).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isFace
                                      ? Icons.face_rounded
                                      : (isGranted ? Icons.key_rounded : Icons.key_off_rounded),
                                  color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            log.residentName,
                                            style: const TextStyle(
                                              color: AppTheme.textLight,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        StatBadge(
                                          label: log.status,
                                          color: isGranted ? AppTheme.statusSafe : AppTheme.statusDanger,
                                          icon: isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.meeting_room_outlined, size: 13, color: AppTheme.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          log.roomName,
                                          style: const TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          '•  ${isFace ? "Face Biometric" : "RFID Card"}',
                                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    if (!isGranted && log.denialReason != null) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.statusDanger.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Denied: ${log.denialReason!.replaceAll('_', ' ')}',
                                          style: const TextStyle(color: AppTheme.statusDanger, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('EEE, MMM d • HH:mm:ss').format(log.timestamp),
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
      selectedColor: AppTheme.accentCyan,
      backgroundColor: AppTheme.primaryCard,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textLight,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
    );
  }
}
