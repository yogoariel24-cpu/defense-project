import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/stat_badge.dart';

class PaymentScreen extends StatefulWidget {
  final VoidCallback onPaymentApproved;

  const PaymentScreen({super.key, required this.onPaymentApproved});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedPlan = 'STANDARD';
  String _selectedMethod = 'CREDIT_CARD';
  final _refController = TextEditingController();
  final _payerNameController = TextEditingController();

  bool _isSubmitting = false;
  bool _isChecking = false;

  Map<String, dynamic>? _paymentData;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _refController.dispose();
    _payerNameController.dispose();
    super.dispose();
  }

  double get _planPrice => _selectedPlan == 'PREMIUM' ? 99.99 : 49.99;

  Future<void> _checkStatus() async {
    setState(() => _isChecking = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final res = await api.getPaymentStatus();

    if (res['success'] == true && res['data'] != null) {
      setState(() {
        _paymentData = res['data'];
        if (_paymentData!['payment_status'] == 'APPROVED') {
          widget.onPaymentApproved();
        }
      });
    }
    setState(() => _isChecking = false);
  }

  Future<void> _submitPayment() async {
    final ref = _refController.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your transaction reference / payment receipt ID.'),
          backgroundColor: AppTheme.statusWarning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final res = await api.submitPayment(
      subscriptionPlan: _selectedPlan,
      paymentMethod: _selectedMethod,
      paymentReference: ref,
      paymentAmount: _planPrice,
    );

    setState(() => _isSubmitting = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted! Awaiting Administrator validation.'),
          backgroundColor: AppTheme.statusSafe,
        ),
      );
      _checkStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Failed to submit payment.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser!;
    final status = _paymentData?['payment_status'] ?? user.paymentStatus;
    final rejectionReason = _paymentData?['rejection_reason'] ?? user.rejectionReason;

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
            const Text('Account Activation', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
            Text('${user.fullName} • ${user.houseName ?? user.houseId}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textLight),
            tooltip: 'Check Status',
            onPressed: _checkStatus,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textMuted),
            tooltip: 'Logout',
            onPressed: auth.logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryDark, Color(0xFF070F1E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header Card
                  if (status == 'SUBMITTED') ...[
                    _buildPendingCard(),
                  ] else if (status == 'REJECTED') ...[
                    _buildRejectedCard(rejectionReason),
                    const SizedBox(height: 16),
                    _buildPaymentForm(),
                  ] else ...[
                    _buildLockedBanner(),
                    const SizedBox(height: 16),
                    _buildPaymentForm(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBanner() {
    return GlassCard(
      borderColor: Colors.amber.withOpacity(0.4),
      backgroundColor: Colors.amber.withOpacity(0.08),
      padding: const EdgeInsets.all(20),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.amber, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Activation Required',
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                SizedBox(height: 4),
                Text(
                  'To protect multi-tenant infrastructure, house controls, sensors, and AI security are locked until subscription is verified by the platform admin.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard() {
    return GlassCard(
      borderColor: AppTheme.accentCyan.withOpacity(0.5),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.accentCyan.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: AppTheme.accentCyan, size: 42),
          ),
          const SizedBox(height: 18),
          const Text(
            'Payment Submitted — Verification Pending',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textLight, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Your payment reference has been recorded and submitted to the Platform Administrator panel for validation.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reference ID:', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                Text(
                  _paymentData?['payment_reference'] ?? 'SUBMITTED',
                  style: const TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: _isChecking
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded, size: 18),
            label: const Text('Check Approval Status'),
            onPressed: _isChecking ? null : _checkStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildRejectedCard(String? reason) {
    return GlassCard(
      borderColor: AppTheme.statusDanger.withOpacity(0.5),
      backgroundColor: AppTheme.statusDanger.withOpacity(0.08),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppTheme.statusDanger, size: 24),
              SizedBox(width: 10),
              Text('Payment Validation Declined', style: TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.w800, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason ?? 'The administrator was unable to verify your transaction reference. Please submit a valid payment receipt.',
            style: const TextStyle(color: AppTheme.textLight, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentForm() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Select Subscription Plan', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),

          // Plan Selection
          Row(
            children: [
              Expanded(
                child: _buildPlanCard('STANDARD', 'Standard Shield', '\$49.99/mo', 'Full AI Security & IoT Automation'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlanCard('PREMIUM', 'Pro Security Hub', '\$99.99/mo', 'Dedicated 24/7 Dispatch Radar'),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const Text('Select Payment Option', style: TextStyle(color: AppTheme.textLight, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // Payment Methods
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMethodChip('CREDIT_CARD', 'Credit Card', Icons.credit_card_rounded),
              _buildMethodChip('MOBILE_MONEY', 'Mobile Money', Icons.phone_android_rounded),
              _buildMethodChip('BANK_TRANSFER', 'Bank Wire', Icons.account_balance_rounded),
              _buildMethodChip('PAYPAL', 'PayPal', Icons.payment_rounded),
            ],
          ),
          const SizedBox(height: 20),

          // Payment Details Form
          TextField(
            controller: _refController,
            decoration: const InputDecoration(
              labelText: 'Transaction Reference / Receipt Code *',
              hintText: 'e.g. TXN_9823719283 or Bank Ref',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _payerNameController,
            decoration: const InputDecoration(
              labelText: 'Payer Account Name / Phone (Optional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPayment,
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('PAY \$${_planPrice.toStringAsFixed(2)} & SUBMIT FOR VALIDATION', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(String planKey, String title, String price, String desc) {
    final isSelected = _selectedPlan == planKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planKey),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue.withOpacity(0.2) : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : Colors.white10,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: isSelected ? AppTheme.accentCyan : AppTheme.textLight, fontWeight: FontWeight.w700, fontSize: 13)),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accentCyan, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String methodKey, String label, IconData icon) {
    final isSelected = _selectedMethod == methodKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = methodKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue : AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMuted,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
