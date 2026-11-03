import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ezinvoice/screens/setup/first_time_setup_screen.dart';
import 'package:ezinvoice/screens/clients/new_client_screen.dart';
import 'package:ezinvoice/screens/invoices/invoice_form_screen.dart';
import 'package:ezinvoice/screens/payments/receive_payment_screen.dart';
import 'package:ezinvoice/screens/ledger/ledger_screen.dart';
import 'package:ezinvoice/screens/search/universal_search_screen.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/drive_sync_provider.dart';
import 'package:ezinvoice/screens/invoices/invoice_preview_screen.dart';
import 'package:ezinvoice/screens/settings/financial_dashboard_screen.dart';
import 'package:ezinvoice/screens/settings/sync_google_drive_screen.dart';
import 'package:ezinvoice/services/amazon_style_invoice_service.dart';
import 'package:intl/intl.dart';

String _getInitials(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words[0][0].toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  DocumentReference _driveDoc() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('settings').doc('google_drive');
  }

  void _showProfileSwitchMenu(BuildContext context, WidgetRef ref) {
    final currentCompany   = ref.read(activeCompanyProvider);
    final allCompaniesAsync = ref.read(companyListProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Switch Company',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (!allCompaniesAsync.hasValue)
                const Center(child: CircularProgressIndicator())
              else
                ...allCompaniesAsync.value!.map((company) {
                  final bool isCurrent = company.id == currentCompany.id;
                  return RadioListTile<String>(
                    value: company.id,
                    groupValue: currentCompany.id,
                    title: Text(company.businessName),
                    onChanged: (value) {
                      if (!isCurrent) switchCompany(ref, company.id);
                      Navigator.pop(sheetContext);
                    },
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FirstTimeSetupScreen()),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Business'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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

  Future<void> _syncAllInvoicePdfs(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      bool isConnected = false;

      try {
        final snap = await _driveDoc().get();
        if (snap.exists) {
          final data = snap.data() as Map<String, dynamic>;
          isConnected = data['connected'] as bool? ?? false;
        }
      } catch (_) {}

      if (!isConnected) {
        final prefs = await SharedPreferences.getInstance();
        isConnected = prefs.getBool('google_drive_connected') ?? false;
      }

      if (!isConnected) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Connect a Google account first'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Connect',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SyncGoogleDriveScreen()),
            ),
          ),
        ));
        return;
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Syncing PDFs to Drive...'),
          duration: Duration(seconds: 60),
        ),
      );

      try {
        final drive = ref.read(driveSyncProvider);
        final prefs = await SharedPreferences.getInstance();

        final googleSignIn = GoogleSignIn(
          scopes: ['https://www.googleapis.com/auth/drive.file'],
        );
        final account = await googleSignIn.signInSilently();
        if (account == null) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(
            content: const Text('Session expired. Please reconnect Google Drive.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reconnect',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncGoogleDriveScreen()),
              ),
            ),
          ));
          await _driveDoc().set({'connected': false, 'email': null,
            'updatedAt': FieldValue.serverTimestamp()});
          await prefs.setBool('google_drive_connected', false);
          await prefs.remove('google_drive_email');
          return;
        }

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
          final hashKey    = 'sync_hash_${inv.invoiceNumber}';
          final savedHash  = prefs.getString(hashKey);
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
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      } catch (e) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    try {
      await Future.wait([
        ref.refresh(invoiceListProvider.future),
        ref.refresh(clientListProvider.future),
      ]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentCompany     = ref.watch(activeCompanyProvider);
    final currentCompanyName = currentCompany.businessName;
    final invoicesAsync      = ref.watch(invoiceListProvider);
    final clientsAsync       = ref.watch(clientListProvider);
    final currencyFormat     = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => _showProfileSwitchMenu(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(currentCompanyName,
                    overflow: TextOverflow.ellipsis, maxLines: 1),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
        centerTitle: false,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UniversalSearchScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sync PDFs to Drive',
            icon: const ImageIcon(AssetImage('assets/icons/cloud_sync.png'), size: 24),
            onPressed: () => _syncAllInvoicePdfs(context, ref),
          ),
          IconButton(
            tooltip: 'Financial Dashboard',
            icon: const ImageIcon(AssetImage('assets/icons/dashboard.png'), size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FinancialDashboardScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _onRefresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick Actions',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.add_circle,
                              label: 'New Invoice',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const InvoiceFormScreen(invoiceData: null),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.person_add,
                              label: 'New Client',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const NewClientScreen(clientData: null),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.payments_outlined,
                              label: 'Receive Payment',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ReceivePaymentScreen(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _QuickActionCard(
                              icon: Icons.menu_book_outlined,
                              label: 'Ledger',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LedgerScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Recent Activity',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                invoicesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('Error loading data: ${error.toString()}')),
                  data: (invoices) {
                    final recentInvoices = invoices.take(10).toList();
                    if (recentInvoices.isEmpty) {
                      return Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: clientsAsync.when(
                          loading: () => const Text('Loading...'),
                          error: (e, s) => const Text('Clients: Error'),
                          data: (clients) =>
                              Text('No recent bills. Clients: ${clients.length}'),
                        ),
                      );
                    }
                    return Column(
                      children: recentInvoices.map((invoice) {
                        final clientDetailAsync =
                        ref.watch(clientDetailProvider(invoice.clientId));
                        return clientDetailAsync.when(
                          loading: () => const ListTile(title: Text('...')),
                          error: (e, s) => const ListTile(title: Text('Client Load Error')),
                          data: (client) {
                            final clientName = client?.businessName ?? 'Client Not Found';
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4.0),
                              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                              elevation: isDark ? 0 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isDark
                                    ? const BorderSide(color: Color(0xFF2C2C2C), width: 1)
                                    : BorderSide.none,
                              ),
                              child: ListTile(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => InvoicePreviewScreen(
                                        invoiceNumber: invoice.invoiceNumber),
                                  ),
                                ),
                                title: Text(clientName),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("Invoice No: ${invoice.invoiceNumber}"),
                                    Text("Date: ${DateFormat('dd MMM yyyy').format(invoice.invoiceDate)}"),
                                  ],
                                ),
                                trailing: Text(
                                  currencyFormat.format(invoice.grandTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1877F2),
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: const Color(0xFF1877F2)),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}