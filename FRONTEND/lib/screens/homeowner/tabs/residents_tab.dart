import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';

class ResidentsTab extends StatelessWidget {
  const ResidentsTab({super.key});

  void _showAddResidentDialog(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context, listen: false);
    final firstNameCtrl = TextEditingController();
    final lastNameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final relationCtrl = TextEditingController(text: 'Family Member');
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
                const Text('Onboard New Resident', style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(controller: firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name *')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(controller: lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name *')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password *', prefixIcon: Icon(Icons.lock_outline))),
                const SizedBox(height: 12),
                TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: 'Relationship (e.g. Spouse, Son)', prefixIcon: Icon(Icons.people_outline))),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (Optional)', prefixIcon: Icon(Icons.phone_outlined))),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
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

                          final success = await houseProvider.addResident({
                            'first_name': firstNameCtrl.text.trim(),
                            'last_name': lastNameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'password': passCtrl.text.trim(),
                            'relationship_to_owner': relationCtrl.text.trim(),
                            'phone_number': phoneCtrl.text.trim(),
                          });

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Resident onboarded successfully.' : 'Failed to onboard resident.'),
                                backgroundColor: success ? AppTheme.statusSafe : AppTheme.statusDanger,
                              ),
                            );
                          }
                        },
                        child: const Text('Add Resident'),
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

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final residents = houseProvider.residents;

    return RefreshIndicator(
      onRefresh: houseProvider.fetchResidents,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'House Residents (${residents.length})',
                  style: const TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Resident'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                  onPressed: () => _showAddResidentDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (residents.isEmpty)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_outlined, color: AppTheme.textMuted, size: 36),
                        SizedBox(height: 10),
                        Text('No sub-residents registered yet.', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                        Text('Tap "Add Resident" to onboard family members.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: residents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, i) {
                  final r = residents[i];
                  final user = r.user;
                  final perms = r.permissions;
                  final fullName = user?.fullName ?? 'Resident';
                  final email = user?.email ?? '';

                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppTheme.accentBlue.withOpacity(0.2),
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'R',
                                style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(fullName, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('$email • ${r.relationshipToOwner}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            StatBadge(
                              label: r.facePhotoUrl != null ? 'BIOMETRIC ✓' : 'NO FACE',
                              color: r.facePhotoUrl != null ? AppTheme.statusSafe : AppTheme.statusWarning,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.statusDanger, size: 20),
                              tooltip: 'Delete Resident',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: AppTheme.primaryCard,
                                    title: const Text('Delete Resident', style: TextStyle(color: Colors.white)),
                                    content: Text('Are you sure you want to remove $fullName from this house?'),
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
                                  await houseProvider.deleteResident(r.id);
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Granular Permissions (Tap to Toggle)', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _permChip('Lights', perms.canControlLights, (val) {
                              houseProvider.updateResidentPermissions(r.id, {'can_control_lights': val});
                            }),
                            _permChip('Cameras', perms.canViewCameras, (val) {
                              houseProvider.updateResidentPermissions(r.id, {'can_view_cameras': val});
                            }),
                            _permChip('Arm Security', perms.canArmSecurity, (val) {
                              houseProvider.updateResidentPermissions(r.id, {'can_arm_security': val});
                            }),
                            _permChip('Emergency', perms.canTriggerEmergency, (val) {
                              houseProvider.updateResidentPermissions(r.id, {'can_trigger_emergency': val});
                            }),
                          ],
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

  Widget _permChip(String title, bool isEnabled, ValueChanged<bool> onToggle) {
    return GestureDetector(
      onTap: () => onToggle(!isEnabled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isEnabled ? AppTheme.accentBlue.withOpacity(0.2) : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isEnabled ? AppTheme.accentBlue : Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isEnabled ? Icons.check_circle_rounded : Icons.cancel_outlined, size: 12, color: isEnabled ? AppTheme.accentCyan : AppTheme.textDim),
            const SizedBox(width: 4),
            Text(title, style: TextStyle(color: isEnabled ? AppTheme.textLight : AppTheme.textDim, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
