import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/drive_sync_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/client_provider.dart';
import '../../services/amazon_style_invoice_service.dart';

class SyncGoogleDriveScreen extends ConsumerStatefulWidget {
  const SyncGoogleDriveScreen({super.key});

  @override
  ConsumerState<SyncGoogleDriveScreen> createState() => _SyncGoogleDriveScreenState();
}

class _SyncGoogleDriveScreenState extends ConsumerState<SyncGoogleDriveScreen> {
  String? _email;
  bool _busy = false;

  // ── Firestore reference ───────────────────────────────────────────────────
  DocumentReference get _driveDoc {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('settings').doc('google_drive');
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // ✅ Read from Firestore first — cross-device sync
    try {
      final snap = await _driveDoc.get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        final connected = data['connected'] as bool? ?? false;
        final email     = data['email'] as String?;
        if (connected && email != null) {
          setState(() => _email = email);
          // Sync to local prefs
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('google_drive_connected', true);
          await prefs.setString('google_drive_email', email);
          return;
        } else if (!connected) {
          // Explicitly disconnected — clear local too
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('google_drive_connected', false);
          await prefs.remove('google_drive_email');
          setState(() => _email = null);
          return;
        }
      }
    } catch (_) {}

    // Fallback to SharedPreferences
    final prefs     = await SharedPreferences.getInstance();
    final connected = prefs.getBool('google_drive_connected') ?? false;
    final email     = prefs.getString('google_drive_email');
    if (connected && email != null) setState(() => _email = email);
  }

  Future<void> _saveConnection(String email) async {
    await _driveDoc.set({'connected': true, 'email': email,
      'updatedAt': FieldValue.serverTimestamp()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_drive_connected', true);
    await prefs.setString('google_drive_email', email);
  }

  Future<void> _clearConnection() async {
    await _driveDoc.set({'connected': false, 'email': null,
      'updatedAt': FieldValue.serverTimestamp()});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('google_drive_connected', false);
    await prefs.remove('google_drive_email');
  }

  Future<void> _pickAccountOrLogout() async {
    final drive = ref.read(driveSyncProvider);

    // ── DISCONNECT ────────────────────────────────────────────────────────────
    if (_email != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Disconnect Drive?'),
          content: Text('Disconnect Google Drive account ($_email)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Disconnect'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await drive.signOut();
        await GoogleSignIn().signOut();
        setState(() => _email = null);
        // ✅ Clear from Firestore — all devices see disconnected
        await _clearConnection();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google Drive disconnected')),
          );
        }
      }
      return;
    }

    // ── CONNECT ───────────────────────────────────────────────────────────────
    try {
      setState(() => _busy = true);

      final googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/drive.file'],
      );
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();

      if (account == null) {
        setState(() => _busy = false);
        return;
      }

      await drive.ensureFolderPath(['Origin Invoice']);
      final email = drive.currentUser?.email ?? account.email;

      setState(() => _email = email);
      // ✅ Save to Firestore — all devices see connected
      await _saveConnection(email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected: $email')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _invoiceHash(invoice) {
    return [
      invoice.invoiceNumber,
      invoice.grandTotal.toString(),
      invoice.invoiceDate.toIso8601String(),
      invoice.clientId,
      invoice.items.length.toString(),
      invoice.cgstTotal.toString(),
      invoice.sgstTotal.toString(),
      invoice.status.toString(),
    ].join('|');
  }

  Future<void> _tapToSync() async {
    if (_email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect a Google account first')),
      );
      return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Syncing PDFs to Drive...'), duration: Duration(seconds: 60)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();

      final googleSignIn = GoogleSignIn(
        scopes: ['https://www.googleapis.com/auth/drive.file'],
      );
      final account = await googleSignIn.signInSilently();
      if (account == null) {
        messenger.hideCurrentSnackBar();
        if (mounted) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Session expired. Please reconnect Google Drive.'),
          ));
          setState(() => _email = null);
        }
        // ✅ Clear from Firestore too
        await _clearConnection();
        return;
      }

      final drive       = ref.read(driveSyncProvider);
      final company     = ref.read(activeCompanyProvider);
      final companyName = company.businessName.isNotEmpty ? company.businessName : 'Company';
      final invoices    = await ref.read(invoiceListProvider.future);

      if (invoices.isEmpty) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(const SnackBar(content: Text('No invoices to sync')));
        return;
      }

      final amazonService = AmazonStyleInvoiceService();
      final folderCache   = <String, String>{};
      int uploaded = 0;
      int skipped  = 0;

      for (final inv in invoices) {
        final hashKey     = 'sync_hash_${inv.invoiceNumber}';
        final savedHash   = prefs.getString(hashKey);
        final currentHash = _invoiceHash(inv);

        if (savedHash == currentHash) { skipped++; continue; }

        final y   = inv.invoiceDate.year.toString();
        final m   = inv.invoiceDate.month.toString().padLeft(2, '0');
        final key = '$y-$m';

        String folderId = folderCache[key] ??
            await drive.ensureFolderPath(['Origin Invoice', 'Invoices', companyName, y, m]);
        folderCache[key] = folderId;

        final client = await ref.read(clientDetailProvider(inv.clientId).future);
        if (client == null) continue;

        final bytes = await amazonService.generatePdf(inv, company, client);
        final name  = 'INV-$y-$m-${inv.invoiceNumber}.pdf';
        await drive.saveInvoicePdf(parentFolderId: folderId, fileName: name, pdfBytes: bytes);

        await prefs.setString(hashKey, currentHash);
        uploaded++;
      }

      messenger.hideCurrentSnackBar();
      final msg = uploaded == 0
          ? 'All invoices already up to date! ($skipped skipped)'
          : 'Synced $uploaded invoice(s). $skipped already up to date.';
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _tile({
    required IconData leading,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(leading, size: 28),
        title: Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: titleColor)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = _email == null
        ? 'Tap to connect a Google account'
        : 'Connected: $_email\n(Tap to disconnect)';

    return Scaffold(
      appBar: AppBar(title: const Text('Sync to Google Drive')),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          _tile(
            leading: _email != null ? Icons.check_circle_outline : Icons.account_circle_outlined,
            title: _email != null ? 'Drive Connected' : 'Connect Google Drive',
            subtitle: sub,
            titleColor: _email != null ? Colors.green : null,
            onTap: _busy ? null : _pickAccountOrLogout,
          ),
          if (_email != null)
            _tile(
              leading: Icons.cloud_upload_outlined,
              title: 'Sync Invoices',
              subtitle: 'Back up all invoice PDFs to Drive',
              onTap: _busy ? null : _tapToSync,
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
