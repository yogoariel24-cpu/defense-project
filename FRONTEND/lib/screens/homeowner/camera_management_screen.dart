import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/house_provider.dart';
import '../../models/camera_model.dart';
import '../../models/room_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';

class CameraManagementScreen extends StatefulWidget {
  const CameraManagementScreen({super.key});

  @override
  State<CameraManagementScreen> createState() => _CameraManagementScreenState();
}

class _CameraManagementScreenState extends State<CameraManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HouseProvider>(context, listen: false).fetchCameras();
    });
  }

  void _showAddCameraDialog(BuildContext context, List<RoomModel> rooms) {
    final nameCtrl = TextEditingController(text: 'Front Entrance Camera');
    final locCtrl = TextEditingController(text: 'Front Door Porch');
    final streamCtrl = TextEditingController(text: 'http://192.168.1.150:81/stream');
    String? selectedRoomId = rooms.isNotEmpty ? rooms.first.id : null;
    String resolution = '1080p';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.videocam_rounded, color: AppTheme.accentCyan, size: 22),
                  SizedBox(width: 10),
                  Text('Add AI Camera', style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Camera Name', hintText: 'e.g. Entrance ESP32-CAM'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(labelText: 'Location Description', hintText: 'e.g. Cardboard Door Access Point'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streamCtrl,
                      decoration: const InputDecoration(labelText: 'Stream URL', hintText: 'http://<esp32-cam-ip>:81/stream'),
                    ),
                    const SizedBox(height: 12),
                    if (rooms.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedRoomId,
                        dropdownColor: AppTheme.primarySurface,
                        decoration: const InputDecoration(labelText: 'Monitored Room / Door'),
                        items: rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                        onChanged: (val) => setModalState(() => selectedRoomId = val),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: resolution,
                      dropdownColor: AppTheme.primarySurface,
                      decoration: const InputDecoration(labelText: 'Resolution'),
                      items: const [
                        DropdownMenuItem(value: 'SVGA', child: Text('SVGA (800x600) - Recommended')),
                        DropdownMenuItem(value: 'VGA', child: Text('VGA (640x480)')),
                        DropdownMenuItem(value: '1080p', child: Text('1080p HD')),
                      ],
                      onChanged: (val) => setModalState(() => resolution = val ?? 'SVGA'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final hp = Provider.of<HouseProvider>(context, listen: false);
                    final success = await hp.addCamera(
                      name: nameCtrl.text.trim(),
                      locationName: locCtrl.text.trim(),
                      streamUrl: streamCtrl.text.trim(),
                      resolution: resolution,
                      roomId: selectedRoomId,
                    );
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Camera added successfully!' : 'Failed to add camera.'),
                          backgroundColor: success ? AppTheme.accentBlue : AppTheme.statusDanger,
                        ),
                      );
                    }
                  },
                  child: const Text('Add Camera'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditCameraDialog(BuildContext context, CameraModel camera, List<RoomModel> rooms) {
    final nameCtrl = TextEditingController(text: camera.locationName);
    final streamCtrl = TextEditingController(text: camera.streamUrl);
    String? selectedRoomId = camera.roomId;
    String resolution = camera.resolution;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return AlertDialog(
              backgroundColor: AppTheme.primaryCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Configure Camera', style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Location / Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streamCtrl,
                      decoration: const InputDecoration(labelText: 'Stream URL'),
                    ),
                    const SizedBox(height: 12),
                    if (rooms.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: selectedRoomId,
                        dropdownColor: AppTheme.primarySurface,
                        decoration: const InputDecoration(labelText: 'Assigned Room'),
                        items: rooms.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                        onChanged: (val) => setModalState(() => selectedRoomId = val),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: resolution,
                      dropdownColor: AppTheme.primarySurface,
                      decoration: const InputDecoration(labelText: 'Resolution'),
                      items: const [
                        DropdownMenuItem(value: 'SVGA', child: Text('SVGA (800x600)')),
                        DropdownMenuItem(value: 'VGA', child: Text('VGA (640x480)')),
                        DropdownMenuItem(value: '1080p', child: Text('1080p HD')),
                      ],
                      onChanged: (val) => setModalState(() => resolution = val ?? 'SVGA'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final hp = Provider.of<HouseProvider>(context, listen: false);
                    final success = await hp.updateCamera(camera.id, {
                      'location_name': nameCtrl.text.trim(),
                      'stream_url': streamCtrl.text.trim(),
                      'resolution': resolution,
                      'room_id': selectedRoomId,
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Camera configured successfully!' : 'Failed to update camera.'),
                          backgroundColor: success ? AppTheme.accentBlue : AppTheme.statusDanger,
                        ),
                      );
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final cameras = houseProvider.cameras;
    final rooms = houseProvider.rooms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Management', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentCyan),
            onPressed: () => houseProvider.fetchCameras(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.accentBlue,
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Add Camera', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        onPressed: () => _showAddCameraDialog(context, rooms),
      ),
      body: RefreshIndicator(
        onRefresh: () => houseProvider.fetchCameras(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status overview card
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: AppTheme.accentCyan, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cameras.length} Registered Cameras',
                          style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${cameras.where((c) => c.isOnline).length} Active & Streaming | Facial AI Ready',
                          style: const TextStyle(color: AppTheme.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (cameras.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 54, color: AppTheme.textMuted.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    const Text('No Cameras Provisioned', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "+ Add Camera" to register your ESP32-CAM AI module.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...cameras.map((cam) => _buildCameraCard(context, cam, rooms)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraCard(BuildContext context, CameraModel camera, List<RoomModel> rooms) {
    final hp = Provider.of<HouseProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Name & Status
            Row(
              children: [
                Icon(
                  Icons.videocam_rounded,
                  color: camera.isActive ? AppTheme.accentCyan : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camera.locationName,
                        style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (camera.roomName != null)
                        Text('Room: ${camera.roomName}', style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
                    ],
                  ),
                ),
                StatBadge(
                  label: camera.isActive ? 'ACTIVE' : 'DEACTIVATED',
                  color: camera.isActive ? AppTheme.statusSafe : AppTheme.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Live Stream Viewer Box
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        camera.isActive ? Icons.camera_indoor_rounded : Icons.videocam_off_rounded,
                        color: camera.isActive ? AppTheme.accentCyan.withOpacity(0.6) : Colors.white24,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        camera.isActive ? 'ESP32-CAM Video Stream' : 'Camera Deactivated',
                        style: TextStyle(
                          color: camera.isActive ? AppTheme.textLight : AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        camera.streamUrl,
                        style: const TextStyle(color: AppTheme.textDim, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (camera.isActive)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        camera.resolution,
                        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Controls Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Switch(
                      value: camera.isActive,
                      activeColor: AppTheme.accentCyan,
                      onChanged: (val) => hp.toggleCameraStatus(camera.id, val),
                    ),
                    Text(
                      camera.isActive ? 'Enabled' : 'Disabled',
                      style: TextStyle(color: camera.isActive ? AppTheme.textLight : AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.textDim, size: 20),
                      tooltip: 'Configure',
                      onPressed: () => _showEditCameraDialog(context, camera, rooms),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.statusDanger, size: 20),
                      tooltip: 'Remove',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: AppTheme.primaryCard,
                            title: const Text('Remove Camera?'),
                            content: Text('Are you sure you want to delete ${camera.locationName}?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          hp.deleteCamera(camera.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
