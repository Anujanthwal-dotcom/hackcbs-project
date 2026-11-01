import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/backend_api_service.dart';
import '../../services/language_service.dart';
import '../../services/semantic_ui_registry.dart';
import '../../services/user_repository.dart';
import '../history/detection_history_screen.dart';

/// User Profile screen displaying authenticated farmer details, history access, and account actions.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService.instance;
    final userRepository = UserRepository.instance;
    final uid = authService.currentUid;
    final l10n = AppLocalizations.of(context)!;
    final langService = LanguageService.instance;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          l10n.profileTitle,
          style: const TextStyle(
            color: Color(0xFF27421D),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<UserProfile?>(
        stream: uid != null ? userRepository.streamUserProfile(uid) : const Stream.empty(),
        builder: (context, snapshot) {
          final user = authService.currentUser;
          final profile = snapshot.data;

          final displayName = profile?.name ?? user?.displayName ?? (langService.isHindi ? 'किसान' : 'Farmer');
          final email = profile?.email ?? user?.email ?? (uid == null ? 'farmer@example.com' : '');
          final displayUid = uid ?? l10n.guestUser;
          final memberSince = profile != null
              ? DateFormat('MMMM yyyy', langService.languageCode).format(profile.createdAt)
              : (langService.isHindi ? 'हाल ही में' : 'Recently');

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Profile Avatar
                Center(
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDCE9C7),
                      border: Border.all(color: const Color(0xFFC5D9A5), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'F',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27421D),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Name & Email
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27421D),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5A7250)),
                ),
                const SizedBox(height: 20),

                // Language Selection Card
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.languageTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF27421D),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Card(
                  color: const Color(0xFFFAFCF5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Color(0xFFE2E9D4), width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ValueListenableBuilder<Locale>(
                      valueListenable: langService.localeNotifier,
                      builder: (context, currentLoc, _) {
                        return Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('English', style: TextStyle(fontWeight: FontWeight.bold))),
                                selected: currentLoc.languageCode == 'en',
                                selectedColor: const Color(0xFF27421D),
                                labelStyle: TextStyle(
                                  color: currentLoc.languageCode == 'en' ? Colors.white : const Color(0xFF27421D),
                                ),
                                onSelected: (sel) {
                                  if (sel) langService.setLocale(const Locale('en'));
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('हिन्दी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold))),
                                selected: currentLoc.languageCode == 'hi',
                                selectedColor: const Color(0xFF27421D),
                                labelStyle: TextStyle(
                                  color: currentLoc.languageCode == 'hi' ? Colors.white : const Color(0xFF27421D),
                                ),
                                onSelected: (sel) {
                                  if (sel) langService.setLocale(const Locale('hi'));
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Account Details Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.accountInformation,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF27421D),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                _buildProfileInfoCard(
                  icon: Icons.person_outline,
                  title: l10n.fullNameLabel,
                  subtitle: displayName,
                ),
                _buildProfileInfoCard(
                  icon: Icons.email_outlined,
                  title: l10n.emailLabel,
                  subtitle: email,
                ),
                _buildProfileInfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: l10n.memberSince,
                  subtitle: memberSince,
                ),
                _buildProfileInfoCard(
                  icon: Icons.fingerprint,
                  title: l10n.userIdLabel,
                  subtitle: displayUid,
                ),

                const SizedBox(height: 16),

                // Diagnosis History Navigation Card
                AgentUiElement(
                  id: 'profile_history',
                  label: 'Diagnosis History',
                  description: 'Opens past crop disease scans and diagnosis records',
                  screen: 'Profile',
                  onTrigger: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DetectionHistoryScreen(),
                      ),
                    );
                  },
                  child: Card(
                    color: const Color(0xFFFAFCF5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Color(0xFFE2E9D4), width: 1.2),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1DB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.history_outlined, color: Color(0xFF27421D), size: 24),
                      ),
                      title: Text(
                        l10n.diagnosisHistory,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF27421D),
                        ),
                      ),
                      subtitle: Text(
                        l10n.diagnosisHistorySubtitle,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF5A7250)),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Color(0xFF7A936A)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DetectionHistoryScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Edit Profile Button
                AgentUiElement(
                  id: 'profile_edit_name',
                  label: 'Edit Profile Name',
                  description: 'Opens a dialog to change your farmer display name',
                  screen: 'Profile',
                  onTrigger: () => _showEditNameDialog(context, displayName, l10n),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showEditNameDialog(context, displayName, l10n),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF27421D),
                        side: const BorderSide(color: Color(0xFF27421D), width: 1.4),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(
                        l10n.editNameTitle,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Sign Out Button
                AgentUiElement(
                  id: 'profile_sign_out',
                  label: 'Sign Out Button',
                  description: 'Signs out of your account on this device',
                  screen: 'Profile',
                  isDestructive: true,
                  onTrigger: () => _confirmSignOut(context, l10n),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _confirmSignOut(context, l10n),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(
                        l10n.signOutButton,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: const Color(0xFFFAFCF5),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E9D4), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1DB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF27421D), size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A7250),
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF27421D),
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName, AppLocalizations l10n) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAFCF5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n.editNameTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
          ),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.fullNameLabel,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF5A7250))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF27421D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(ctx);
                  await AuthService.instance.updateDisplayName(newName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.profileUpdated)),
                    );
                  }
                }
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFAFCF5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            l10n.signOutConfirmTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF27421D)),
          ),
          content: Text(
            l10n.signOutConfirmMessage,
            style: const TextStyle(fontSize: 14, color: Color(0xFF5A7250)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel, style: const TextStyle(color: Color(0xFF5A7250))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await AuthService.instance.signOut();
                await BackendApiService.instance.logout();
              },
              child: Text(l10n.signOutButton),
            ),
          ],
        );
      },
    );
  }
}
