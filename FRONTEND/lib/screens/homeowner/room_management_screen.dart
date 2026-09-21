import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/house_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';
import '../../models/room_model.dart';
import 'room_permissions_screen.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HouseProvider>(context, listen: false).fetchRooms();
    });
  }

  IconData _getRoomIcon(String roomType) {
    switch (roomType) {
      case 'ENTRANCE':
        return Icons.door_front_door_rounded;
      case 'LIVING_ROOM':
        return Icons.weekend_rounded;
      case 'BEDROOM':
        return Icons.bed_rounded;
      case 'OFFICE':
        return Icons.computer_rounded;
      case 'KITCHEN':
        return Icons.kitchen_rounded;
      case 'STORAGE':
        return Icons.inventory_2_rounded;
      case 'CORRIDOR':
        return Icons.meeting_room_rounded;
      default:
        return Icons.room_preferences_rounded;
    }
  }

  void _showRoomDialog([RoomModel? room]) {
    final nameCtrl = TextEditingController(text: room?.name ?? '');
    final descCtrl = TextEditingController(text: room?.description ?? '');
    String selectedType = room?.roomType ?? 'LIVING_ROOM';
    bool isRestricted = room?.isRestricted ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.primaryCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            room == null ? 'Add New Room' : 'Edit Room',
            style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'e.g. Master Bedroom, Living Room',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  dropdownColor: AppTheme.primaryCard,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(labelText: 'Room Type'),
                  items: const [
                    DropdownMenuItem(value: 'ENTRANCE', child: Text('Front Entrance')),
                    DropdownMenuItem(value: 'LIVING_ROOM', child: Text('Living Room')),
                    DropdownMenuItem(value: 'BEDROOM', child: Text('Bedroom')),
                    DropdownMenuItem(value: 'OFFICE', child: Text('Office / Study')),
                    DropdownMenuItem(value: 'KITCHEN', child: Text('Kitchen')),
                    DropdownMenuItem(value: 'STORAGE', child: Text('Secure Storage / Server')),
                    DropdownMenuItem(value: 'CORRIDOR', child: Text('Corridor / Hallway')),
                    DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Notes, hardware notes, security rules...',
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Restricted Access', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Requires explicit database permission to unlock', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  value: isRestricted,
                  activeColor: AppTheme.accentCyan,
                  onChanged: (val) => setDlgState(() => isRestricted = val),
                ),
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
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final provider = Provider.of<HouseProvider>(context, listen: false);
                Navigator.pop(ctx);

                if (room == null) {
                  await provider.createRoom(
                    name: name,
                    roomType: selectedType,
                    description: descCtrl.text.trim(),
                    isRestricted: isRestricted,
                  );
                } else {
                  await provider.updateRoom(
                    room.id,
                    name: name,
                    roomType: selectedType,
                    description: descCtrl.text.trim(),
                    isRestricted: isRestricted,
                  );
                }
              },
              child: Text(room == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RoomModel room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.primaryCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Room?', style: TextStyle(color: AppTheme.statusDanger)),
        content: Text(
          'Are you sure you want to delete "${room.name}"? Associated room permissions will also be removed.',
          style: const TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<HouseProvider>(context, listen: false).deleteRoom(room.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final rooms = houseProvider.rooms;

    return Scaffold(
      backgroundColor: AppTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Room Access Management', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: AppTheme.primaryCard,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => houseProvider.fetchRooms(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Room', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showRoomDialog(),
      ),
      body: RefreshIndicator(
        onRefresh: () => houseProvider.fetchRooms(),
        child: rooms.isEmpty
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
                          child: const Icon(Icons.meeting_room_outlined, size: 56, color: AppTheme.accentCyan),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Rooms Configured Yet',
                          style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Define rooms in your house to enable dynamic database-driven access control for RFID cards and facial recognition.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create First Room'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                          onPressed: () => _showRoomDialog(),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final room = rooms[idx];
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
                                color: (room.isRestricted ? AppTheme.accentOrange : AppTheme.accentCyan).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getRoomIcon(room.roomType),
                                color: room.isRestricted ? AppTheme.accentOrange : AppTheme.accentCyan,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.name,
                                    style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    room.roomType.replaceAll('_', ' '),
                                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            StatBadge(
                              label: room.isRestricted ? 'RESTRICTED' : 'STANDARD',
                              color: room.isRestricted ? AppTheme.accentOrange : AppTheme.statusSafe,
                              icon: room.isRestricted ? Icons.lock_rounded : Icons.lock_open_rounded,
                            ),
                          ],
                        ),
                        if (room.description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(room.description, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                        const SizedBox(height: 14),
                        const Divider(color: Colors.white12, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.vpn_key_rounded, size: 16),
                              label: Text('Permissions (${room.permissions.length})'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => RoomPermissionsScreen(room: room)),
                                );
                              },
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.textMuted),
                              tooltip: 'Edit Room',
                              onPressed: () => _showRoomDialog(room),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.statusDanger),
                              tooltip: 'Delete Room',
                              onPressed: () => _confirmDelete(room),
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
