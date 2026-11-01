import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../widgets/nature_background.dart';

/// User Registration / Create Account screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('[AUTH] handleRegister initiated');
      await _authService.registerWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        debugPrint('[NAV] Registration successful — popping to root AuthGate (Home)');
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('[AUTH] handleRegister error caught: $e');
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF27421D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: NatureBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.createAccountTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF27421D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.createAccountSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF5A7250),
                      ),
                    ),
                    const SizedBox(height: 24),

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

                    // Full Name Field
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.fullNameLabel,
                        hintText: l10n.fullNameHint,
                        prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF27421D)),
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
                          return l10n.fullNameRequired;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

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
                    const SizedBox(height: 14),

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
                        if (val.length < 6) {
                          return l10n.passwordLength;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password Field
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                        hintText: l10n.confirmPasswordHint,
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF27421D)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: const Color(0xFF5A7250),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
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
                          return l10n.confirmPasswordRequired;
                        }
                        if (val != _passwordController.text) {
                          return l10n.passwordsDoNotMatch;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    FilledButton(
                      onPressed: _isLoading ? null : _handleRegister,
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
                              l10n.registerButton,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Back to Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l10n.alreadyHaveAccount} ',
                          style: const TextStyle(color: Color(0xFF5A7250), fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            l10n.signInButton,
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
        ),
      ),
    );
  }
}
