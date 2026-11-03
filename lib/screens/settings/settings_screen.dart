// lib/screens/settings/settings_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ezinvoice/screens/company/company_details_edit_screen.dart';
import 'package:ezinvoice/screens/settings/bank_details_screen.dart';
import 'package:ezinvoice/screens/settings/invoice_template_screen.dart';
import 'package:ezinvoice/screens/settings/logo_signature_screen.dart';
import 'package:ezinvoice/screens/setup/first_time_setup_screen.dart';
import 'package:ezinvoice/screens/auth/onboarding_screen.dart';
import 'package:ezinvoice/screens/auth/profile_screen.dart';
import 'package:ezinvoice/screens/settings/export_data_screen.dart';
import 'package:ezinvoice/screens/settings/sync_google_drive_screen.dart';
import 'financial_dashboard_screen.dart';
import 'package:ezinvoice/screens/settings/invoice_settings_screen.dart';

import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/providers/theme_provider.dart';
import 'package:ezinvoice/providers/invoice_template_provider.dart';

// ── Profile photo provider (loads Base64 from Firestore) ─────────────────────
final profilePhotoProvider = FutureProvider<String?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data()?['profilePhotoBase64'] as String?;
  } catch (_) {
    return null;
  }
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _blue = Color(0xFF1877F2);

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: _blue),
            SizedBox(width: 8),
            Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Need help? Contact us and we\'ll get back to you as soon as possible.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.email_outlined, color: _blue, size: 20),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'dheerajkushwaha2563@gmail.com',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.email, size: 16),
            label: const Text('Send Email'),
            style: FilledButton.styleFrom(backgroundColor: _blue),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final uri = Uri(
                scheme: 'mailto',
                path: 'dheerajkushwaha2563@gmail.com',
                query: 'subject=Origin Invoice Support',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open email app')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCompany = ref.watch(activeCompanyProvider);
    final currentTheme = ref.watch(themeProvider);
    final selectedTemplate = ref.watch(invoiceTemplateProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
      },
      child: StreamBuilder(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('More'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  tooltip: 'Help & Support',
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => _showHelpDialog(context),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                await ref.read(companyListProvider.notifier).refresh();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [

                  // ── COMPANY DETAILS ─────────────────────────────────────────
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text('COMPANY DETAILS',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1.5)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.business),
                          title: const Text('Company Details'),
                          subtitle: const Text('Edit business information'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompanyDetailsEditScreen(company: currentCompany))),
                        ),
                        ListTile(
                          leading: const Icon(Icons.account_balance),
                          title: const Text('Bank Details'),
                          subtitle: const Text('Manage bank account information'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BankDetailsScreen(company: currentCompany))),
                        ),
                        ListTile(
                          leading: const Icon(Icons.image),
                          title: const Text('Logo & Signature'),
                          subtitle: const Text('Upload company logo and signature'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogoSignatureScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.sync_alt),
                          title: const Text('Switch Company'),
                          subtitle: Text('Current: ${currentCompany.businessName}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showSwitchCompanySheet(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── BACKUP & DATA ────────────────────────────────────────────
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text('BACKUP & DATA',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1.5)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: const Text('Sync to Google Drive'),
                          subtitle: const Text('Backup invoice PDFs to Drive'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SyncGoogleDriveScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: const Text('Export Data'),
                          subtitle: const Text('Export invoices as PDF & EXCEL'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExportDataScreen())),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── OTHER SETTINGS ───────────────────────────────────────────
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text('OTHER SETTINGS',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1.5)),
                        ),
                        ListTile(
                          leading: const Icon(Icons.pie_chart_outline),
                          title: const Text('Financial Dashboard'),
                          subtitle: const Text('View sales, taxes and client stats'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinancialDashboardScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: const Text('Invoice Settings'),
                          subtitle: const Text('Default GST rates'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoiceSettingsScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.description),
                          title: const Text('Invoice Template'),
                          subtitle: Text(selectedTemplate.displayName),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoiceTemplateScreen())),
                        ),
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text('App Theme'),
                          subtitle: Text(_getThemeDescription(currentTheme)),
                          trailing: DropdownButton<ThemeMode>(
                            value: currentTheme,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                              DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                              DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                            ],
                            onChanged: (ThemeMode? newTheme) {
                              if (newTheme != null) ref.read(themeProvider.notifier).setThemeMode(newTheme);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── ACCOUNT ──────────────────────────────────────────────────
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Text('ACCOUNT',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1.5)),
                        ),
                        ListTile(
                          // ── FIXED: Load avatar from Firestore Base64 ──────────
                          leading: Consumer(
                            builder: (context, ref, _) {
                              final photoAsync = ref.watch(profilePhotoProvider);
                              final user = FirebaseAuth.instance.currentUser;

                              final initials = (user?.displayName?.isNotEmpty == true)
                                  ? user!.displayName![0].toUpperCase()
                                  : (user?.email?.isNotEmpty == true)
                                  ? user!.email![0].toUpperCase()
                                  : '?';

                              return photoAsync.when(
                                data: (base64Photo) {
                                  ImageProvider? image;
                                  if (base64Photo != null) {
                                    image = MemoryImage(base64Decode(base64Photo));
                                  } else if (user?.photoURL != null) {
                                    image = NetworkImage(user!.photoURL!);
                                  }
                                  return CircleAvatar(
                                    backgroundColor: const Color(0xFFFC363B).withValues(alpha: 0.15),
                                    backgroundImage: image,
                                    child: image == null
                                        ? Text(initials,
                                        style: const TextStyle(
                                            color: Color(0xFFFC363B),
                                            fontWeight: FontWeight.bold))
                                        : null,
                                  );
                                },
                                loading: () => CircleAvatar(
                                  backgroundColor: const Color(0xFFFC363B).withValues(alpha: 0.15),
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Color(0xFFFC363B),
                                          fontWeight: FontWeight.bold)),
                                ),
                                error: (_, __) => CircleAvatar(
                                  backgroundColor: const Color(0xFFFC363B).withValues(alpha: 0.15),
                                  child: Text(initials,
                                      style: const TextStyle(
                                          color: Color(0xFFFC363B),
                                          fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                          title: Text(
                            FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty == true
                                ? FirebaseAuth.instance.currentUser!.displayName!
                                : FirebaseAuth.instance.currentUser?.email ?? 'My Account',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('View profile details'),
                          trailing: const Icon(Icons.chevron_right),
                          // ── FIXED: Invalidate provider on return so photo refreshes ──
                          onTap: () async {
                            await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfileScreen()));
                            ref.invalidate(profilePhotoProvider);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          subtitle: const Text('Update your account password'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showChangePasswordDialog(context),
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Log Out'),
                          subtitle: const Text('Log out of your account'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showLogoutDialog(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Made with ❤️ by 𝗗𝗞 𝗚𝗿𝗼𝘂𝗽',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isEmailUser = user?.providerData.any((p) => p.providerId == 'password') ?? false;

    if (!isEmailUser) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Password change is only for email accounts. Google accounts don\'t have a password.'),
        backgroundColor: const Color(0xFFFC363B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool loading = false;
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _passwordField(currentPasswordController, 'Current Password', isDark: isDark),
                const SizedBox(height: 10),
                _passwordField(newPasswordController, 'New Password', isDark: isDark),
                const SizedBox(height: 10),
                _passwordField(confirmPasswordController, 'Confirm New Password', isDark: isDark),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: loading ? null : () async {
                  if (newPasswordController.text != confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                    return;
                  }
                  if (newPasswordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                    return;
                  }
                  setDialogState(() => loading = true);
                  try {
                    final credential = EmailAuthProvider.credential(
                      email: user!.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);
                    await user.updatePassword(newPasswordController.text);
                    if (ctx.mounted) Navigator.of(dialogContext).pop();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Password changed successfully! ✅'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  } on FirebaseAuthException catch (e) {
                    setDialogState(() => loading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message ?? 'Failed'), backgroundColor: const Color(0xFFFC363B)),
                    );
                  }
                },
                child: loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update', style: TextStyle(color: _blue, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, String label, {bool isDark = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: controller,
        obscureText: true,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : const Color(0xFF2C2C2C)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          floatingLabelStyle: const TextStyle(fontSize: 12, color: Color(0xFF1877F2), fontWeight: FontWeight.w600),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          border: UnderlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
          filled: false,
          isDense: false,
          contentPadding: const EdgeInsets.only(top: 8, bottom: 10),
        ),
      ),
    );
  }

  void _showSwitchCompanySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) {
        return Consumer(builder: (sheetContext, ref, _) {
          final companiesAsync = ref.watch(companyListProvider);
          final activeCompany = ref.watch(activeCompanyProvider);
          final scheme = Theme.of(sheetContext).colorScheme;
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                top: 8,
              ),
              child: companiesAsync.when(
                loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
                error: (e, s) => SizedBox(height: 160, child: Center(child: Text('Error: ${e.toString()}'))),
                data: (companies) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Switch Company',
                        style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    if (companies.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No businesses yet.'))
                    else
                      ...companies.map((c) {
                        final isActive = c.id == activeCompany.id;
                        return RadioListTile<String>(
                          value: c.id,
                          groupValue: activeCompany.id,
                          title: Text(c.businessName, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
                          activeColor: scheme.primary,
                          onChanged: (value) {
                            if (value != null && value != activeCompany.id) {
                              ref.read(activeCompanyIdProvider.notifier).state = value;
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched to ${c.businessName}')));
                            } else {
                              Navigator.pop(sheetContext);
                            }
                          },
                        );
                      }),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Business'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Future.microtask(() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FirstTimeSetupScreen())));
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await GoogleSignIn().signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('google_drive_connected', false);
              await prefs.remove('google_drive_email');
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                      (route) => false,
                );
              }
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getThemeDescription(ThemeMode theme) {
    switch (theme) {
      case ThemeMode.light: return 'Always use light theme';
      case ThemeMode.dark:  return 'Always use dark theme';
      default:              return 'Follow system settings';
    }
  }
}
