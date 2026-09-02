import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _homeowners = [];
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'totalHouses': 0,
    'totalDevices': 0,
    'activeAlarms': 0,
  };
  bool _isLoading = true;
  String _searchQuery = '';
  bool _filterPendingOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final statsRes = await api.getAdminStats();
    if (statsRes['success'] == true && statsRes['data'] != null) {
      _stats = statsRes['data'];
    }

    final homeownersRes = await api.getAdminHomeowners();
    if (homeownersRes['success'] == true && homeownersRes['data']?['homeowners'] != null) {
      _homeowners = homeownersRes['data']['homeowners'];
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handlePaymentApproval(String userId, String action, {String? reason}) async {
    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.validateAdminPayment(userId, action, rejectionReason: reason);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'APPROVE' ? 'Payment validated! Account activated and unlocked.' : 'Payment marked as rejected.'),
          backgroundColor: action == 'APPROVE' ? AppTheme.statusSafe : AppTheme.statusDanger,
        ),
      );
      _fetchAdminData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'] ?? 'Action failed'), backgroundColor: AppTheme.statusDanger),
      );
    }
  }

  void _showRejectDialog(String userId, String name) {
    final reasonCtrl = TextEditingController(text: 'Transaction reference could not be verified.');
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.primaryCard,
        title: Text('Reject Payment for $name', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('State the reason for rejecting this transaction:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Rejection Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () {
              Navigator.pop(c);
              _handlePaymentApproval(userId, 'REJECT', reason: reasonCtrl.text.trim());
            },
            child: const Text('Reject Payment'),
          ),
        ],
      ),
    );
  }

  void _showProvisionDialog() {
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final houseNameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.primaryCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_home_work_rounded, color: AppTheme.accentCyan, size: 24),
                    SizedBox(width: 10),
                    Text('Provision Homeowner & House', style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name *'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name *'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Initial Password (min 8 chars) *', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 12),
                TextField(controller: houseNameCtrl, decoration: const InputDecoration(labelText: 'House Name (e.g. Hilltop Villa)', prefixIcon: Icon(Icons.home_outlined))),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || passCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all mandatory fields'), backgroundColor: AppTheme.statusWarning),
                            );
                            return;
                          }

                          if (passCtrl.text.trim().length < 8) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password must be at least 8 digits/characters long'), backgroundColor: AppTheme.statusDanger),
                            );
                            return;
                          }

                          final api = Provider.of<ApiService>(context, listen: false);
                          final res = await api.createAdminHomeowner({
                            'first_name': firstNameCtrl.text.trim(),
                            'last_name': lastNameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'password': passCtrl.text.trim(),
                            'house_name': houseNameCtrl.text.trim().isNotEmpty ? houseNameCtrl.text.trim() : '${lastNameCtrl.text.trim()} Residence',
                            'address': addressCtrl.text.trim().isNotEmpty ? addressCtrl.text.trim() : '123 Smart Ave',
                            'phone_number': phoneCtrl.text.trim(),
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['success'] == true ? 'Homeowner & house provisioned successfully.' : (res['message'] ?? 'Failed to provision')),
                                backgroundColor: res['success'] == true ? AppTheme.statusSafe : AppTheme.statusDanger,
                              ),
                            );
                            _fetchAdminData();
                          }
                        },
                        child: const Text('Provision'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddDeviceDialog(Map<String, dynamic> homeowner, {Map<String, dynamic>? prefillOrder}) {
    final house = homeowner['house'] ?? {};
    final houseId = house['id'] ?? '';
    final houseName = house['name'] ?? 'Residence';

    String selectedType = prefillOrder?['device_type'] ?? 'CAMERA';
    if (selectedType == 'ALARM_HUB') selectedType = 'ESP32';

    final identifierCtrl = TextEditingController(
      text: prefillOrder != null ? '${prefillOrder['device_type']}_${houseId}_01' : 'DEV_${houseId}_01',
    );
    final nameCtrl = TextEditingController(
      text: prefillOrder?['device_name'] ?? (selectedType == 'CAMERA' ? 'Perimeter Security Camera' : 'Living Room Light'),
    );
    final ipCtrl = TextEditingController(text: '192.168.1.150');
    final macCtrl = TextEditingController(text: '24:0A:C4:B8:3D:1F');
    final streamOrLocCtrl = TextEditingController(
      text: selectedType == 'CAMERA' ? 'http://192.168.1.150:81/stream' : 'Living Room Area',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppTheme.primaryCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.memory_rounded, color: AppTheme.accentCyan, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Provision Hardware Device ($houseName)',
                            style: const TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    if (prefillOrder != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
                        ),
                        child: Text(
                          'Fulfilling Order: ${prefillOrder['device_name']} (\$${prefillOrder['total_price']}) • Ref: ${prefillOrder['payment_reference']}',
                          style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: ['CAMERA', 'SMART_LIGHT', 'MOTION_SENSOR', 'LIGHT_SENSOR', 'ESP32'].contains(selectedType) ? selectedType : 'CAMERA',
                      dropdownColor: AppTheme.primaryCard,
                      decoration: const InputDecoration(labelText: 'Device Type *', prefixIcon: Icon(Icons.category_outlined)),
                      items: const [
                        DropdownMenuItem(value: 'CAMERA', child: Text('📷 AI Security Camera (ESP32-CAM)')),
                        DropdownMenuItem(value: 'SMART_LIGHT', child: Text('💡 Smart PWM Light Bulb')),
                        DropdownMenuItem(value: 'MOTION_SENSOR', child: Text('📡 PIR Motion Detector')),
                        DropdownMenuItem(value: 'LIGHT_SENSOR', child: Text('☀️ Ambient Light Sensor (LDR)')),
                        DropdownMenuItem(value: 'ESP32', child: Text('🚨 Emergency Siren / Panic Alarm Hub')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                            if (val == 'CAMERA') {
                              nameCtrl.text = 'Perimeter Camera';
                              streamOrLocCtrl.text = 'http://192.168.1.150:81/stream';
                            } else if (val == 'SMART_LIGHT') {
                              nameCtrl.text = 'Main Living Room Bulb';
                              streamOrLocCtrl.text = 'Living Room';
                            } else if (val == 'MOTION_SENSOR') {
                              nameCtrl.text = 'Front Porch Motion Sensor';
                              streamOrLocCtrl.text = 'Front Porch';
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: identifierCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hardware Device Identifier *',
                        hintText: 'e.g. CAM_FRONT_01 or LIGHT_01',
                        prefixIcon: Icon(Icons.qr_code_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Display Name *',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ipCtrl,
                            decoration: const InputDecoration(labelText: 'IP Address', hintText: '192.168.1.150'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: macCtrl,
                            decoration: const InputDecoration(labelText: 'MAC Address', hintText: '24:0A:C4:...'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: streamOrLocCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == 'CAMERA' ? 'RTSP / HTTP Stream URL' : 'Installation Location',
                        prefixIcon: Icon(selectedType == 'CAMERA' ? Icons.videocam_outlined : Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                            onPressed: () async {
                              if (identifierCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Identifier and Name are required'), backgroundColor: AppTheme.statusWarning),
                                );
                                return;
                              }

                              final api = Provider.of<ApiService>(context, listen: false);
                              final res = await api.provisionDeviceToHouse(houseId, {
                                'device_identifier': identifierCtrl.text.trim(),
                                'name': nameCtrl.text.trim(),
                                'type': selectedType,
                                'ip_address': ipCtrl.text.trim(),
                                'mac_address': macCtrl.text.trim(),
                                'order_id': prefillOrder?['id'],
                                'specific_config': {
                                  'location_name': streamOrLocCtrl.text.trim(),
                                  if (selectedType == 'CAMERA') 'stream_url': streamOrLocCtrl.text.trim(),
                                },
                              });

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res['success'] == true ? 'Hardware device provisioned to $houseName!' : (res['message'] ?? 'Provisioning failed')),
                                    backgroundColor: res['success'] == true ? AppTheme.statusSafe : AppTheme.statusDanger,
                                  ),
                                );
                                _fetchAdminData();
                              }
                            },
                            child: const Text('Provision Device', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> homeowner) {
    final user = homeowner['user'] ?? {};
    final house = homeowner['house'] ?? {};
    final userId = user['id'] ?? '';

    final firstNameCtrl = TextEditingController(text: user['first_name'] ?? '');
    final lastNameCtrl = TextEditingController(text: user['last_name'] ?? '');
    final emailCtrl = TextEditingController(text: user['email'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone_number'] ?? '');
    final houseNameCtrl = TextEditingController(text: house['name'] ?? '');
    final addressCtrl = TextEditingController(text: house['address'] ?? '');
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.primaryCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: AppTheme.accentCyan, size: 24),
                    SizedBox(width: 10),
                    Text('Edit Homeowner Account', style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name'))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 12),
                TextField(controller: houseNameCtrl, decoration: const InputDecoration(labelText: 'House Name', prefixIcon: Icon(Icons.home_outlined))),
                const SizedBox(height: 12),
                TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Reset Password (Leave blank to keep)', prefixIcon: Icon(Icons.lock_reset_outlined))),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final api = Provider.of<ApiService>(context, listen: false);
                          final res = await api.updateAdminHomeowner(userId, {
                            'first_name': firstNameCtrl.text.trim(),
                            'last_name': lastNameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone_number': phoneCtrl.text.trim(),
                            'house_name': houseNameCtrl.text.trim(),
                            'address': addressCtrl.text.trim(),
                            if (passCtrl.text.trim().isNotEmpty) 'password': passCtrl.text.trim(),
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res['success'] == true ? 'Homeowner updated successfully.' : (res['message'] ?? 'Failed to update')),
                                backgroundColor: res['success'] == true ? AppTheme.statusSafe : AppTheme.statusDanger,
                              ),
                            );
                            _fetchAdminData();
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE';
    final api = Provider.of<ApiService>(context, listen: false);

    final res = await api.updateAccountStatus(userId, newStatus);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account status changed to $newStatus (all house residents updated)'),
          backgroundColor: newStatus == 'ACTIVE' ? AppTheme.statusSafe : AppTheme.statusDanger,
        ),
      );
      _fetchAdminData();
    }
  }

  Future<void> _deleteUser(String userId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppTheme.primaryCard,
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to permanently delete $name and their house instance? This will remove all associated devices and residents.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.deleteAccount(userId);
      if (res['success'] == true) {
        _fetchAdminData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    final filteredHomeowners = _homeowners.where((h) {
      final user = h['user'] ?? {};
      final house = h['house'] ?? {};
      final paymentStatus = h['payment_status'] ?? 'PENDING';

      if (_filterPendingOnly && paymentStatus == 'APPROVED') {
        return false;
      }

      final query = _searchQuery.toLowerCase();
      final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.toLowerCase();
      final email = (user['email'] ?? '').toLowerCase();
      final houseId = (house['id'] ?? '').toLowerCase();
      final houseName = (house['name'] ?? '').toLowerCase();
      return fullName.contains(query) || email.contains(query) || houseId.contains(query) || houseName.contains(query);
    }).toList();

    final pendingCount = _homeowners.where((h) => h['payment_status'] == 'SUBMITTED' || h['payment_status'] == 'PENDING').length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 24),
            SizedBox(width: 10),
            Text('Platform Administration'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textLight),
            tooltip: 'Refresh',
            onPressed: _fetchAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted),
            tooltip: 'Logout',
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentCyan))
          : RefreshIndicator(
              onRefresh: _fetchAdminData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Stat Cards
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL HOUSES', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text('${_stats['totalHouses'] ?? _homeowners.length}', style: const TextStyle(color: AppTheme.accentCyan, fontSize: 26, fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassCard(
                            borderColor: pendingCount > 0 ? Colors.amber.withOpacity(0.5) : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('PAYMENT REVIEW', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(
                                  '$pendingCount Pending',
                                  style: TextStyle(color: pendingCount > 0 ? Colors.amber : AppTheme.statusSafe, fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TOTAL DEVICES', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 8),
                                Text(
                                  '${_stats['totalDevices'] ?? 0}',
                                  style: const TextStyle(color: AppTheme.textLight, fontSize: 26, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Provision Homeowner CTA Banner
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppTheme.accentCyan.withOpacity(0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accentCyan, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Create Homeowner Account', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w800, fontSize: 14)),
                                Text('Register homeowner, generate credentials & provision house', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('PROVISION'),
                            onPressed: _showProvisionDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filter & Search Header
                    Row(
                      children: [
                        const Text('Homeowner Accounts & Houses', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        _buildFilterButton('ALL', !_filterPendingOnly, () => setState(() => _filterPendingOnly = false)),
                        const SizedBox(width: 8),
                        _buildFilterButton('PENDING PAYMENTS', _filterPendingOnly, () => setState(() => _filterPendingOnly = true), isAlert: pendingCount > 0),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Search Field
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by homeowner name, email, or house ID...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    const SizedBox(height: 16),

                    // Homeowners List
                    if (filteredHomeowners.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: GlassCard(
                            child: Column(
                              children: [
                                const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                const Text('No homeowner accounts found.', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                const Text('Try switching filter tabs or provisioning a new house.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredHomeowners.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final h = filteredHomeowners[index];
                          final user = h['user'] ?? {};
                          final house = h['house'] ?? {};
                          final status = user['status'] ?? 'ACTIVE';
                          final isActive = status == 'ACTIVE';
                          final fullName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                          final email = user['email'] ?? '';
                          final houseId = house['id'] ?? 'N/A';
                          final houseName = house['name'] ?? 'Residence';
                          final residents = house['residents'] as List? ?? [];
                          final devices = house['devices'] as List? ?? [];
                          final deviceOrders = house['deviceOrders'] as List? ?? [];

                          final paymentStatus = h['payment_status'] ?? 'PENDING';
                          final isPaid = paymentStatus == 'APPROVED';
                          final paymentPlan = h['subscription_plan'] ?? 'STANDARD';
                          final paymentRef = h['payment_reference'] ?? 'None';
                          final paymentMethod = h['payment_method'] ?? 'N/A';

                          Color payColor = AppTheme.statusWarning;
                          if (paymentStatus == 'APPROVED') payColor = AppTheme.statusSafe;
                          if (paymentStatus == 'SUBMITTED') payColor = AppTheme.accentCyan;
                          if (paymentStatus == 'REJECTED') payColor = AppTheme.statusDanger;

                          return GlassCard(
                            padding: const EdgeInsets.all(16),
                            borderColor: !isPaid ? payColor.withOpacity(0.5) : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                                      child: Text(
                                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'H',
                                        style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(fullName.isNotEmpty ? fullName : 'Homeowner', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 15)),
                                          const SizedBox(height: 2),
                                          Text('$email • $houseId ($houseName)', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    StatBadge(
                                      label: 'STATUS: $status',
                                      color: isActive ? AppTheme.statusSafe : AppTheme.statusDanger,
                                    ),
                                    const SizedBox(width: 6),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: AppTheme.textMuted),
                                      color: AppTheme.primarySurface,
                                      onSelected: (val) {
                                        if (val == 'add_device') {
                                          _showAddDeviceDialog(h);
                                        } else if (val == 'edit') {
                                          _showEditDialog(h);
                                        } else if (val == 'toggle') {
                                          _toggleStatus(user['id'], status);
                                        } else if (val == 'delete') {
                                          _deleteUser(user['id'], fullName);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(
                                          value: 'add_device',
                                          child: Row(
                                            children: [
                                              Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.accentCyan),
                                              SizedBox(width: 8),
                                              Text('Add / Provision Device', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w700)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18, color: AppTheme.textLight),
                                              SizedBox(width: 8),
                                              Text('Edit Details'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Row(
                                            children: [
                                              Icon(isActive ? Icons.block_flipped : Icons.check_circle_outline, size: 18, color: isActive ? AppTheme.statusDanger : AppTheme.statusSafe),
                                              SizedBox(width: 8),
                                              Text(isActive ? 'Suspend Account' : 'Activate Account', style: TextStyle(color: isActive ? AppTheme.statusDanger : AppTheme.statusSafe)),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 18, color: AppTheme.statusDanger),
                                              SizedBox(width: 8),
                                              Text('Delete Account', style: TextStyle(color: AppTheme.statusDanger)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Hardware & Info Box
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primarySurface,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Plan: $paymentPlan • Ref: $paymentRef ($paymentMethod)',
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                      ),
                                      Text(
                                        '${residents.length} Residents • ${devices.length} Devices',
                                        style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),

                                // Pending Device Orders from Homeowner
                                if (deviceOrders.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  ...deviceOrders.where((ord) => ord['provision_status'] == 'ORDERED').map((ord) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.shopping_cart_outlined, color: Colors.amber, size: 16),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Ordered: ${ord['device_name']} (\$${ord['total_price']}) • Ref: ${ord['payment_reference']}',
                                              style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.amber,
                                              foregroundColor: Colors.black,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            onPressed: () => _showAddDeviceDialog(h, prefillOrder: ord),
                                            child: const Text('Provision Device'),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],

                                const SizedBox(height: 10),
                                // Action Buttons Row: Add Device beside Suspend Account & Edit
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.memory_rounded, size: 16),
                                        label: const Text('Add Device'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.accentBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                        onPressed: () => _showAddDeviceDialog(h),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      icon: Icon(isActive ? Icons.block_flipped : Icons.check_circle_outline, size: 16, color: isActive ? AppTheme.statusDanger : AppTheme.statusSafe),
                                      label: Text(isActive ? 'Suspend' : 'Activate', style: TextStyle(color: isActive ? AppTheme.statusDanger : AppTheme.statusSafe)),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: isActive ? AppTheme.statusDanger : AppTheme.statusSafe),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => _toggleStatus(user['id'], status),
                                    ),
                                  ],
                                ),

                                // Admin Validation Action Buttons if payment is pending
                                if (!isPaid) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                                          label: const Text('Validate & Activate Payment'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.statusSafe,
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          onPressed: () => _handlePaymentApproval(user['id'], 'APPROVE'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.cancel_outlined, size: 16, color: AppTheme.statusDanger),
                                        label: const Text('Reject', style: TextStyle(color: AppTheme.statusDanger)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppTheme.statusDanger),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: () => _showRejectDialog(user['id'], fullName),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterButton(String label, bool isSelected, VoidCallback onTap, {bool isAlert = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAlert ? Colors.amber : (isSelected ? AppTheme.accentBlue : Colors.white10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isAlert ? Colors.amber : AppTheme.textMuted),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
