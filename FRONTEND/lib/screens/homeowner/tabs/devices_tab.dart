import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/house_provider.dart';
import '../../../services/api_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/stat_badge.dart';

class DevicesTab extends StatefulWidget {
  const DevicesTab({super.key});

  @override
  State<DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends State<DevicesTab> {
  List<dynamic> _deviceOrders = [];
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _fetchDeviceOrders();
  }

  Future<void> _fetchDeviceOrders() async {
    setState(() => _isLoadingOrders = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.getHouseDeviceOrders();
    if (res['success'] == true && res['data']?['orders'] != null) {
      _deviceOrders = res['data']['orders'];
    }
    if (mounted) setState(() => _isLoadingOrders = false);
  }

  void _showOrderHardwareDialog(BuildContext context) {
    String selectedType = 'CAMERA';
    double unitPrice = 49.99;
    final nameCtrl = TextEditingController(text: 'Front Porch AI Camera');
    final locCtrl = TextEditingController(text: 'Front Entrance');
    String paymentMethod = 'MOBILE_MONEY';
    final refCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
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
                        Icon(Icons.shopping_bag_outlined, color: AppTheme.accentCyan, size: 24),
                        SizedBox(width: 10),
                        Text('Order Hardware Device', style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Select your IoT device, initiate payment, and platform admin will provision your hardware.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 16),

                    // Device Catalog Selection
                    const Text('1. Choose Device Type', style: TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    _buildCatalogCard(
                      title: 'AI Security Camera (ESP32-CAM)',
                      price: '\$49.99',
                      icon: Icons.videocam_rounded,
                      color: AppTheme.accentCyan,
                      isSelected: selectedType == 'CAMERA',
                      onTap: () => setModalState(() {
                        selectedType = 'CAMERA';
                        unitPrice = 49.99;
                        nameCtrl.text = 'Perimeter Security Camera';
                      }),
                    ),
                    const SizedBox(height: 6),
                    _buildCatalogCard(
                      title: 'Smart Dimmer Light Bulb (PWM)',
                      price: '\$19.99',
                      icon: Icons.lightbulb_rounded,
                      color: Colors.orangeAccent,
                      isSelected: selectedType == 'SMART_LIGHT',
                      onTap: () => setModalState(() {
                        selectedType = 'SMART_LIGHT';
                        unitPrice = 19.99;
                        nameCtrl.text = 'Living Room Smart Light';
                      }),
                    ),
                    const SizedBox(height: 6),
                    _buildCatalogCard(
                      title: 'PIR Motion Detector Sensor',
                      price: '\$24.99',
                      icon: Icons.sensors_rounded,
                      color: AppTheme.statusWarning,
                      isSelected: selectedType == 'MOTION_SENSOR',
                      onTap: () => setModalState(() {
                        selectedType = 'MOTION_SENSOR';
                        unitPrice = 24.99;
                        nameCtrl.text = 'Front Yard Motion Sensor';
                      }),
                    ),
                    const SizedBox(height: 6),
                    _buildCatalogCard(
                      title: 'Emergency Siren & Panic Hub',
                      price: '\$39.99',
                      icon: Icons.notifications_active_rounded,
                      color: AppTheme.statusDanger,
                      isSelected: selectedType == 'ALARM_HUB',
                      onTap: () => setModalState(() {
                        selectedType = 'ALARM_HUB';
                        unitPrice = 39.99;
                        nameCtrl.text = 'Emergency Siren Hub';
                      }),
                    ),
                    const SizedBox(height: 16),

                    // Device Customization
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Device Label / Name *')),
                    const SizedBox(height: 10),
                    TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Target Room / Location')),
                    const SizedBox(height: 16),

                    // Payment Details
                    const Text('2. Payment & Checkout', style: TextStyle(color: AppTheme.textLight, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      dropdownColor: AppTheme.primaryCard,
                      decoration: const InputDecoration(labelText: 'Payment Method *', prefixIcon: Icon(Icons.payment_rounded)),
                      items: const [
                        DropdownMenuItem(value: 'MOBILE_MONEY', child: Text('📱 Mobile Money (MTN / Orange)')),
                        DropdownMenuItem(value: 'CREDIT_CARD', child: Text('💳 Credit / Debit Card (Visa / MC)')),
                        DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('🏦 Direct Bank Wire Transfer')),
                        DropdownMenuItem(value: 'PAYPAL', child: Text('🅿 PayPal')),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          paymentMethod = v!;
                          refCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 10),

                    // Dynamic fields per payment method
                    if (paymentMethod == 'MOBILE_MONEY') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.phone_android_rounded, color: Colors.green, size: 16),
                                SizedBox(width: 6),
                                Text('Mobile Money Details', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: refCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number *',
                                hintText: '+237 6XX XXX XXX',
                                prefixIcon: Icon(Icons.call_rounded),
                                helperText: 'MTN MoMo or Orange Money number used for payment',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (paymentMethod == 'CREDIT_CARD') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.credit_card_rounded, color: AppTheme.accentCyan, size: 16),
                                SizedBox(width: 6),
                                Text('Card Details', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Card Number *',
                                hintText: 'XXXX XXXX XXXX XXXX',
                                prefixIcon: Icon(Icons.credit_card_rounded),
                              ),
                              onChanged: (v) => refCtrl.text = 'CARD:$v',
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.datetime,
                                    decoration: const InputDecoration(
                                      labelText: 'Expiry (MM/YY) *',
                                      hintText: '08/28',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'CVV *',
                                      hintText: '•••',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Cardholder Name *',
                                hintText: 'As printed on card',
                                prefixIcon: Icon(Icons.person_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (paymentMethod == 'BANK_TRANSFER') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.purple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_rounded, color: Colors.purple, size: 16),
                                SizedBox(width: 6),
                                Text('Bank Wire Transfer', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Transfer to Vigilis Account:', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                                  SizedBox(height: 4),
                                  Text('Bank: Afriland First Bank', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                                  Text('Account: 00011-20000-12345678901-75', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                                  Text('SWIFT: CCEICMCX', style: TextStyle(color: AppTheme.textLight, fontSize: 12)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: refCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Wire Transfer Reference / Receipt *',
                                hintText: 'e.g. TXN-20240901-12345',
                                prefixIcon: Icon(Icons.receipt_long_rounded),
                                helperText: 'Enter the reference from your bank receipt',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Sending Bank Name',
                                hintText: 'e.g. UBA, Ecobank, BICEC',
                                prefixIcon: Icon(Icons.business_rounded),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (paymentMethod == 'PAYPAL') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003087).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF009CDE).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF009CDE), size: 16),
                                SizedBox(width: 6),
                                Text('PayPal Payment', style: TextStyle(color: Color(0xFF009CDE), fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: refCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'PayPal Email Address *',
                                hintText: 'your-email@example.com',
                                prefixIcon: Icon(Icons.email_rounded),
                                helperText: 'Email used to send payment to vigilis@platform.com',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Total Price Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount Due:', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w600)),
                          Text(
                            '\$${unitPrice.toStringAsFixed(2)}',
                            style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Cancel'))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan, foregroundColor: Colors.black),
                            onPressed: () async {
                              if (refCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(_getRefRequiredMessage(paymentMethod)),
                                    backgroundColor: AppTheme.statusWarning,
                                  ),
                                );
                                return;
                              }

                              // Capture everything before closing dialog
                              final api = Provider.of<ApiService>(dialogCtx, listen: false);
                              final scaffoldMsg = ScaffoldMessenger.of(context);
                              final payRef = refCtrl.text.trim();
                              final devName = nameCtrl.text.trim();
                              final selType = selectedType;
                              final selMethod = paymentMethod;

                              // Close dialog FIRST to avoid blank screen
                              Navigator.pop(dialogCtx);

                              final res = await api.orderDevice({
                                'device_type': selType,
                                'device_name': devName,
                                'payment_method': selMethod,
                                'payment_reference': payRef,
                                'quantity': 1,
                              });

                              scaffoldMsg.showSnackBar(
                                SnackBar(
                                  content: Text(res['success'] == true
                                      ? '✅ Hardware order placed! Awaiting admin provisioning.'
                                      : (res['message'] ?? 'Order failed. Please try again.')),
                                  backgroundColor: res['success'] == true ? AppTheme.statusSafe : AppTheme.statusDanger,
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                              _fetchDeviceOrders();
                            },
                            child: const Text('Submit Order', style: TextStyle(fontWeight: FontWeight.bold)),
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

  String _getRefRequiredMessage(String method) {
    switch (method) {
      case 'MOBILE_MONEY': return 'Please enter your mobile money phone number';
      case 'CREDIT_CARD': return 'Please enter your card number';
      case 'BANK_TRANSFER': return 'Please enter your bank wire transfer reference';
      case 'PAYPAL': return 'Please enter your PayPal email address';
      default: return 'Please fill in your payment details';
    }
  }

  Widget _buildCatalogCard({
    required String title,
    required String price,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textLight,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              price,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final houseProvider = Provider.of<HouseProvider>(context);
    final devices = houseProvider.devices;

    return RefreshIndicator(
      onRefresh: () async {
        await houseProvider.fetchDevices();
        await _fetchDeviceOrders();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Connected Hardware',
                  style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text('Order Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _showOrderHardwareDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pending Orders Section
            if (_deviceOrders.isNotEmpty) ...[
              const Text('Hardware Orders & Provisioning Status', style: TextStyle(color: AppTheme.textLight, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._deviceOrders.map((ord) {
                final isProvisioned = ord['provision_status'] == 'PROVISIONED';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isProvisioned ? AppTheme.statusSafe.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isProvisioned ? AppTheme.statusSafe.withOpacity(0.3) : Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(isProvisioned ? Icons.check_circle_outline : Icons.hourglass_top_rounded, color: isProvisioned ? AppTheme.statusSafe : Colors.amber, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ord['device_name'] ?? 'Device', style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 13)),
                            Text('Ref: ${ord['payment_reference']} • Total: \$${ord['total_price']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      StatBadge(
                        label: isProvisioned ? 'PROVISIONED' : 'AWAITING ADMIN',
                        color: isProvisioned ? AppTheme.statusSafe : Colors.amber,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            if (devices.isEmpty)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.devices_outlined, color: AppTheme.textMuted, size: 36),
                        SizedBox(height: 10),
                        Text('No active IoT devices provisioned yet.', style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Tap "Order Device" to request a Camera, Sensor, or Smart Light.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final d = devices[i];
                  final typeIcon = _iconForType(d.type);
                  final typeColor = _colorForType(d.type);

                  return GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.name, style: const TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  d.type.replaceAll('_', ' '),
                                  if (d.locationName != null) '• ${d.locationName}',
                                  if (d.ipAddress != null) '• ${d.ipAddress}',
                                ].join(' '),
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                              ),
                              if (d.type == 'SMART_LIGHT' && d.brightness != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Brightness: ${d.brightness}% • ${d.isOn == true ? "ON" : "OFF"}',
                                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                              if (d.type == 'LIGHT_SENSOR' && d.currentLux != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${d.currentLux!.toStringAsFixed(1)} Lux  (Threshold: ${d.thresholdLux?.toStringAsFixed(0)} Lux)',
                                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                        StatBadge(
                          label: d.status,
                          color: d.isOnline ? AppTheme.statusSafe : AppTheme.statusDanger,
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

  IconData _iconForType(String type) {
    switch (type) {
      case 'ESP32': return Icons.developer_board_rounded;
      case 'ESP32_CAM': case 'CAMERA': return Icons.videocam_rounded;
      case 'MOTION_SENSOR': return Icons.sensors_rounded;
      case 'LIGHT_SENSOR': return Icons.wb_twilight_rounded;
      case 'SMART_LIGHT': return Icons.lightbulb_rounded;
      default: return Icons.device_hub_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'ESP32': return AppTheme.accentBlue;
      case 'ESP32_CAM': case 'CAMERA': return AppTheme.accentCyan;
      case 'MOTION_SENSOR': return AppTheme.statusWarning;
      case 'LIGHT_SENSOR': return Colors.amber;
      case 'SMART_LIGHT': return Colors.orangeAccent;
      default: return AppTheme.textMuted;
    }
  }
}
