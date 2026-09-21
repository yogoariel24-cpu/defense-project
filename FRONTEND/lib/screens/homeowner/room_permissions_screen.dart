import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../models/room_model.dart';
import '../../models/resident_model.dart';

class RoomPermissionsScreen extends StatefulWidget {
  final RoomModel room;

  const RoomPermissionsScreen({super.key, required this.room});

  @override
  State<RoomPermissionsScreen> createState() => _RoomPermissionsScreenState();
}

class _RoomPermissionsScreenState extends State<RoomPermissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<HouseProvider>(context, listen: false);
      provider.fetchResidents();
      provider.fetchRooms();
    });
  }

  void _editSchedule(ResidentModel resident, RoomPermissionModel? perm) {
    final startCtrl = TextEditingController(text: perm?.scheduleStart ?? '');
    final endCtrl = TextEditingController(text: perm?.scheduleEnd ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Schedule Restriction: ${resident.fullName}',
          style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Specify authorized access hours (24h format HH:MM). Leave blank for 24/7 unlimited access.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: startCtrl,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: const InputDecoration(labelText: 'Start Time', hintText: '08:00'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: endCtrl,
                    style: const TextStyle(color: AppTheme.textLight),
                    decoration: const InputDecoration(labelText: 'End Time', hintText: '18:00'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = Provider.of<HouseProvider>(context, listen: false);
              await provider.setRoomPermission(
                widget.room.id,
                resident.id,
                canAccess: perm?.canAccess ?? true,
                scheduleStart: startCtrl.text.trim().isEmpty ? null : startCtrl.text.trim(),
                scheduleEnd: endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
                isActive: true,
              );
              setState(() {});
            },
            child: const Text('Save Schedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final residents = houseProvider.residents;

    // Find the latest room data from provider
    final currentRoom = houseProvider.rooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: Text('${currentRoom.name} Permissions', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.primaryCard,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await houseProvider.fetchRooms();
          await houseProvider.fetchResidents();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(16),
              borderColor: currentRoom.isRestricted ? AppTheme.accentOrange.withOpacity(0.5) : AppTheme.accentCyan.withOpacity(0.5),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (currentRoom.isRestricted ? AppTheme.accentOrange : AppTheme.accentCyan).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      currentRoom.isRestricted ? Icons.lock_rounded : Icons.lock_open_rounded,
                      color: currentRoom.isRestricted ? AppTheme.accentOrange : AppTheme.accentCyan,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentRoom.name,
                          style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentRoom.isRestricted
                              ? 'Restricted room — only residents granted explicit permission can enter.'
                              : 'Standard room — accessible to residents unless explicitly toggled off.',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'RESIDENT ACCESS RIGHTS (DATABASE ENFORCED)',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            if (residents.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No residents registered yet.', style: TextStyle(color: AppTheme.textMuted)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: residents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final resident = residents[idx];

                  // Match permission from room
                  final perm = currentRoom.permissions.cast<RoomPermissionModel?>().firstWhere(
                        (p) => p?.residentId == resident.id,
                        orElse: () => null,
                      );

                  final hasAccess = perm != null ? perm.canAccess : !currentRoom.isRestricted;
                  final hasSchedule = perm?.scheduleStart != null && perm?.scheduleEnd != null;

                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accentCyan.withOpacity(0.15),
                          child: Text(
                            resident.fullName.isNotEmpty ? resident.fullName[0].toUpperCase() : 'R',
                            style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                resident.fullName,
                                style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                resident.relationshipToOwner,
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                              if (hasSchedule) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 12, color: AppTheme.accentCyan),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${perm!.scheduleStart} – ${perm.scheduleEnd}',
                                      style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            hasSchedule ? Icons.alarm_on_rounded : Icons.alarm_add_rounded,
                            color: hasSchedule ? AppTheme.accentCyan : AppTheme.textMuted,
                            size: 20,
                          ),
                          tooltip: 'Set Time Schedule',
                          onPressed: () => _editSchedule(resident, perm),
                        ),
                        Switch(
                          value: hasAccess,
                          activeColor: AppTheme.statusSafe,
                          onChanged: (val) async {
                            await houseProvider.setRoomPermission(
                              currentRoom.id,
                              resident.id,
                              canAccess: val,
                              scheduleStart: perm?.scheduleStart,
                              scheduleEnd: perm?.scheduleEnd,
                              isActive: true,
                            );
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
