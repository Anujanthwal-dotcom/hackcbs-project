import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import '../../widgets/nature_background.dart';

/// Clean, branded splash/loading screen displayed while checking Firebase authentication state.
class SplashAuthScreen extends StatelessWidget {
  final String? message;

  const SplashAuthScreen({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMsg = message ?? l10n?.initializingApp ?? 'Initializing KisaanBandhu...';

    return Scaffold(
      body: NatureBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE9C7),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC5D9A5), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF27421D).withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco,
                    size: 48,
                    color: Color(0xFF27421D),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n?.sihBranding ?? 'KisaanBandhu • SIH 2026',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF27421D),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.appSubtitle ?? 'Smart Crop Disease & Pest Diagnosis',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF5A7250),
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF27421D),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                displayMsg,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF5A7250),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
