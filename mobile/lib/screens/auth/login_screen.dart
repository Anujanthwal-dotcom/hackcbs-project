import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/backend_api_service.dart';
import '../../widgets/nature_background.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// User Login screen supporting Firebase Authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Navigation is handled automatically by AuthGate stream listener.
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = AuthService.getFriendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showServerConfigDialog() {
    final controller = TextEditingController(text: BackendApiService.instance.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend Server URL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'http://127.0.0.1:3000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('USB (127.0.0.1)'),
                  onPressed: () => controller.text = 'http://127.0.0.1:3000',
                ),
                ActionChip(
                  label: const Text('Wi-Fi (192.168.1.7)'),
                  onPressed: () => controller.text = 'http://192.168.1.7:3000',
                ),
                ActionChip(
                  label: const Text('Emulator (10.0.2.2)'),
                  onPressed: () => controller.text = 'http://10.0.2.2:3000',
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF27421D)),
            onPressed: () async {
              await BackendApiService.instance.setCustomBackendUrl(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: NatureBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.dns_outlined, color: Color(0xFF27421D)),
                  tooltip: 'Configure Backend Server',
                  onPressed: _showServerConfigDialog,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Brand Icon & Title
                        Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCE9C7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC5D9A5), width: 2),
                        ),
                        child: const Icon(
                          Icons.eco,
                          size: 40,
                          color: Color(0xFF27421D),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.loginTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF27421D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF5A7250),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 20, color: Colors.red.shade800),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l10n.emailLabel,
                        hintText: l10n.emailHint,
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF27421D)),
                        filled: true,
                        fillColor: const Color(0xFFFAFCF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E9D4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E9D4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF27421D), width: 1.8),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return l10n.emailRequired;
                        }
                        final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                        if (!emailRegex.hasMatch(val.trim())) {
                          return l10n.emailInvalid;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.passwordLabel,
                        hintText: l10n.passwordHint,
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF27421D)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF5A7250),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAFCF5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E9D4)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E9D4)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF27421D), width: 1.8),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return l10n.passwordRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF27421D),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Login Button
                    FilledButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF27421D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              l10n.signInButton,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l10n.dontHaveAccount} ',
                          style: const TextStyle(color: Color(0xFF5A7250), fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: _isLoading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: Text(
                            l10n.registerButton,
                            style: const TextStyle(
                              color: Color(0xFF27421D),
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}
}
