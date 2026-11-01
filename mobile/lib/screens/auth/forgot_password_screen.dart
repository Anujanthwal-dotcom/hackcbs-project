import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/nature_background.dart';

/// Password recovery screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService = AuthService.instance;

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.sendPasswordResetEmail(_emailController.text);
      if (mounted) {
        setState(() {
          _emailSent = true;
        });
      }
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

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: _emailSent ? _buildSuccessState() : _buildFormState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE9C7),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC5D9A5), width: 2),
              ),
              child: const Icon(
                Icons.lock_reset,
                size: 38,
                color: Color(0xFF27421D),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reset Password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF27421D),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email address and we will send you a link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF5A7250)),
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

          // Email Field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Email Address',
              hintText: 'farmer@example.com',
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
                return 'Please enter your email address.';
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
              if (!emailRegex.hasMatch(val.trim())) {
                return 'Please enter a valid email format.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Send Reset Link Button
          FilledButton(
            onPressed: _isLoading ? null : _handleReset,
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
                : const Text(
                    'Send Reset Link',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Back to Sign In',
              style: TextStyle(
                color: Color(0xFF27421D),
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF1DB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 42,
              color: Color(0xFF27421D),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Password Reset Email Sent',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF27421D),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We have sent a password reset link to ${_emailController.text}. Please check your inbox and follow instructions.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF5A7250)),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF27421D),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Back to Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
