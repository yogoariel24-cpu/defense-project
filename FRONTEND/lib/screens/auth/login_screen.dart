import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignUpMode = false;

  // Sign In Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Create Account Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _houseNameController = TextEditingController();
  final _addressController = TextEditingController();

  bool _obscurePassword = true;
  String? _passwordError;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _phoneController.dispose();
    _houseNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _validateRegPassword(String val) {
    setState(() {
      if (val.isEmpty) {
        _passwordError = 'Password is required';
      } else if (val.length < 8) {
        _passwordError = 'Password must be at least 8 digits/characters';
      } else {
        _passwordError = null;
      }
    });
  }

  void _submitLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
          backgroundColor: AppTheme.statusWarning,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.login(email, password);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Authentication failed. Please check your credentials.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  void _submitSignUp() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final pass = _regPasswordController.text;
    final email = _regEmailController.text.trim();

    bool hasError = false;

    if (pass.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 digits/characters');
      hasError = true;
    } else {
      setState(() => _passwordError = null);
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() => _emailError = 'Please enter a valid email address');
      hasError = true;
    } else {
      setState(() => _emailError = null);
    }

    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your First and Last Name.'),
          backgroundColor: AppTheme.statusWarning,
        ),
      );
      return;
    }

    if (hasError) return;

    final success = await auth.registerHomeowner(
      email: email,
      password: pass,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      houseName: _houseNameController.text.trim().isNotEmpty
          ? _houseNameController.text.trim()
          : '${_lastNameController.text.trim()} Residence',
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : '123 Smart Ave',
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed.'),
          backgroundColor: AppTheme.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand Header with Vigilis Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.6), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.3),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.accentBlue.withOpacity(0.2),
                            child: const Icon(Icons.shield_rounded, color: AppTheme.accentCyan, size: 44),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'V I G I L I S',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textLight,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Intelligent Multi-House Security & Automation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2-Way Switch: Sign In / Create Account
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isSignUpMode = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isSignUpMode ? AppTheme.accentBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'Sign In',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: !_isSignUpMode ? Colors.white : AppTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isSignUpMode = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isSignUpMode ? AppTheme.accentBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                'Create Account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _isSignUpMode ? Colors.white : AppTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Form Card
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: _isSignUpMode ? _buildSignUpForm(auth) : _buildLoginForm(auth),
                  ),
                  const SizedBox(height: 18),
                  _buildServerSelectorBadge(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Portal Login',
          style: TextStyle(
            color: AppTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in with your registered account credentials',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Account Email',
            hintText: 'e.g. name@example.com',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textDim,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: auth.isLoading ? null : _submitLogin,
          child: auth.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('AUTHENTICATE'),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Register Homeowner & House',
          style: TextStyle(
            color: AppTheme.textLight,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Provision a new house instance on the Vigilis Platform',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *', prefixIcon: Icon(Icons.person_outline)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name *'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
          decoration: InputDecoration(
            labelText: 'Email Address *',
            prefixIcon: const Icon(Icons.email_outlined),
            errorText: _emailError,
            errorStyle: const TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _regPasswordController,
          obscureText: _obscurePassword,
          onChanged: _validateRegPassword,
          decoration: InputDecoration(
            labelText: 'Password (min 8 characters) *',
            prefixIcon: const Icon(Icons.lock_outline),
            errorText: _passwordError,
            errorStyle: const TextStyle(color: AppTheme.statusDanger, fontWeight: FontWeight.bold),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.statusDanger, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.statusDanger, width: 1.5),
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textDim),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _houseNameController,
          decoration: const InputDecoration(labelText: 'House Name (e.g. Serenity Villa)', prefixIcon: Icon(Icons.home_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressController,
          decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: auth.isLoading ? null : _submitSignUp,
          child: auth.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('CREATE HOUSE & ACCOUNT'),
        ),
      ],
    );
  }

  Widget _buildServerSelectorBadge() {
    final isCloud = ApiService.isUsingRemote;
    final serverName = isCloud ? 'Railway Cloud' : 'Local Backend';
    final serverColor = isCloud ? AppTheme.statusSafe : AppTheme.accentCyan;

    return Center(
      child: InkWell(
        onTap: _showServerConfigDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: serverColor.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: serverColor,
                  boxShadow: [
                    BoxShadow(color: serverColor.withOpacity(0.6), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Server: $serverName',
                style: const TextStyle(
                  color: AppTheme.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.tune_rounded, size: 14, color: AppTheme.textDim),
            ],
          ),
        ),
      ),
    );
  }

  void _showServerConfigDialog() {
    bool isCloud = ApiService.useRemoteBackend && ApiService.customServerUrl == null;
    final customUrlCtrl = TextEditingController(
      text: ApiService.customServerUrl ?? ApiService.defaultLocalUrl,
    );
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.primarySurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.dns_rounded, color: AppTheme.accentCyan, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Backend Server',
                    style: TextStyle(color: AppTheme.textLight, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Choose where your app sends API requests. You can easily switch between your Railway deployment and local development without touching backend code.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 16),

                    // Railway Cloud Option
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          isCloud = true;
                          testResult = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isCloud ? AppTheme.accentBlue.withOpacity(0.18) : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCloud ? AppTheme.accentCyan : Colors.white10,
                            width: isCloud ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Radio<bool>(
                              value: true,
                              groupValue: isCloud,
                              activeColor: AppTheme.accentCyan,
                              onChanged: (val) {
                                setDialogState(() {
                                  isCloud = true;
                                  testResult = null;
                                });
                              },
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Railway Cloud (Production)',
                                    style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'defense-project-production.up.railway.app',
                                    style: TextStyle(color: AppTheme.statusSafe, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Local Backend Option
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          isCloud = false;
                          testResult = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: !isCloud ? AppTheme.accentBlue.withOpacity(0.18) : Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !isCloud ? AppTheme.accentCyan : Colors.white10,
                            width: !isCloud ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<bool>(
                                  value: false,
                                  groupValue: isCloud,
                                  activeColor: AppTheme.accentCyan,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      isCloud = false;
                                      testResult = null;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Local Development Server',
                                        style: TextStyle(color: AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Run backend locally with npm run dev',
                                        style: TextStyle(color: AppTheme.textDim, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (!isCloud) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: customUrlCtrl,
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  labelText: 'Local API URL',
                                  labelStyle: const TextStyle(fontSize: 12),
                                  hintText: 'e.g. http://192.168.1.130:5000/api',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, size: 16),
                                    tooltip: 'Reset to default local URL',
                                    onPressed: () {
                                      setDialogState(() {
                                        customUrlCtrl.text = ApiService.defaultLocalUrl;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (testSuccess ?? false)
                              ? AppTheme.statusSafe.withOpacity(0.12)
                              : AppTheme.statusDanger.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (testSuccess ?? false) ? AppTheme.statusSafe : AppTheme.statusDanger,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (testSuccess ?? false) ? Icons.check_circle : Icons.error_outline,
                              color: (testSuccess ?? false) ? AppTheme.statusSafe : AppTheme.statusDanger,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                testResult!,
                                style: TextStyle(
                                  color: (testSuccess ?? false) ? AppTheme.statusSafe : AppTheme.statusDanger,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isTesting
                          ? null
                          : () async {
                              setDialogState(() {
                                isTesting = true;
                                testResult = 'Testing connectivity...';
                                testSuccess = null;
                              });

                              final target = isCloud
                                  ? ApiService.remoteUrl
                                  : customUrlCtrl.text.trim();

                              final health = await ApiService.checkHealth(target);

                              setDialogState(() {
                                isTesting = false;
                                if (health['success'] == true) {
                                  testSuccess = true;
                                  testResult = 'Online! Latency: ${health['latencyMs']}ms (${health['data']?['service'] ?? 'Vigilis API'})';
                                } else {
                                  testSuccess = false;
                                  testResult = 'Failed to reach: ${health['message'] ?? 'Check connection or URL'}';
                                }
                              });
                            },
                      icon: isTesting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bolt, size: 16),
                      label: Text(isTesting ? 'Checking...' : 'Test Connection'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (isCloud) {
                      await ApiService.setServerMode(isRemote: true);
                    } else {
                      final url = customUrlCtrl.text.trim();
                      await ApiService.setServerMode(
                        isRemote: false,
                        customUrl: url.isNotEmpty ? url : null,
                      );
                    }
                    if (mounted) {
                      setState(() {});
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Connected to: ${ApiService.baseUrl}'),
                          backgroundColor: AppTheme.accentBlue,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: const Text('Save & Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
