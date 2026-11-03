import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/screens/clients/new_client_screen.dart';
import 'package:ezinvoice/screens/payments/receive_payment_screen.dart';
import 'package:ezinvoice/screens/ledger/ledger_screen.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientName;

  const ClientDetailScreen({
    super.key,
    required this.clientName,
  });

  Client _findClient(WidgetRef ref) {
    final clientsAsyncValue = ref.watch(clientListProvider);

    const Client clientNotFound = Client(
      id: 'C_ERROR',
      businessName: 'Client Not Found',
      billingAddress: '',
      billingCity: '',
      billingState: '',
      billingPincode: '',
      shippingAddress: '',
      shippingCity: '',
      shippingState: '',
      shippingPincode: '',
    );

    const Client clientLoading = Client(
      id: 'C_LOADING',
      businessName: 'Loading...',
      billingAddress: '',
      billingCity: '',
      billingState: '',
      billingPincode: '',
      shippingAddress: '',
      shippingCity: '',
      shippingState: '',
      shippingPincode: '',
    );

    if (clientsAsyncValue.hasValue) {
      return clientsAsyncValue.value!.firstWhere(
            (c) => c.businessName == clientName,
        orElse: () => clientNotFound,
      );
    }

    return clientLoading;
  }

  Future<void> _deleteClient(
      BuildContext context,
      WidgetRef ref,
      String clientId,
      String clientName,
      ) async {
    // Optimistic — pop and show snackbar instantly
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$clientName deleted'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 1),
      ),
    );

    // Delete in background
    ref.read(clientListProvider.notifier).deleteClient(clientId);
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context,
      WidgetRef ref,
      Client client,
      ) async {
    if (client.id.contains('ERROR') ||
        client.id.contains('LOADING')) {
      return;
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to permanently delete ${client.businessName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();

              _deleteClient(
                context,
                ref,
                client.id,
                client.businessName,
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
      BuildContext context, {
        required String title,
        required List<Widget> children,
      }) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.white,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark
            ? const BorderSide(
          color: Color(0xFF2C2C2C),
          width: 1,
        )
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1877F2),
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION BUTTON
  // ============================================================

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1877F2),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final client = _findClient(ref);

    if (client.id.contains('LOADING')) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isSameAddress =
        client.billingAddress ==
            client.shippingAddress;

    final hasBilling =
        client.billingAddress?.isNotEmpty ?? false;

    final billingFull = hasBilling
        ? '${client.billingAddress}, '
        '${client.billingCity}, '
        '${client.billingState} - '
        '${client.billingPincode}'
        : 'Not provided';

    final shippingFull = isSameAddress
        ? 'Same as Billing Address'
        : (client.shippingAddress?.isNotEmpty ??
        false)
        ? '${client.shippingAddress}, '
        '${client.shippingCity}, '
        '${client.shippingState} - '
        '${client.shippingPincode}'
        : 'Not provided';

    return Scaffold(
      appBar: AppBar(
        title: Text(client.businessName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewClientScreen(
                      clientData: client,
                    ),
                  ),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // GST INFORMATION
                  if (client.gstNumber != null &&
                      client.gstNumber!.isNotEmpty)
                    _infoCard(
                      context,
                      title: 'GST Information',
                      children: [
                        _infoRow(
                          Icons.gavel,
                          'GST Number',
                          client.gstNumber!,
                        ),
                      ],
                    ),

                  // BILLING ADDRESS
                  _infoCard(
                    context,
                    title: 'Billing Address',
                    children: [
                      _infoRow(
                        Icons.location_on_outlined,
                        'Address',
                        billingFull,
                      ),
                    ],
                  ),

                  // SHIPPING ADDRESS
                  _infoCard(
                    context,
                    title: 'Shipping Address',
                    children: [
                      _infoRow(
                        Icons.local_shipping_outlined,
                        'Address',
                        shippingFull,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // ========================================================
                  // PAYMENT & LEDGER ACTIONS
                  // ========================================================

                  Row(
                    children: [
                      _actionButton(
                        context: context,
                        icon: Icons.payments_outlined,
                        label: 'Receive Payment',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReceivePaymentScreen(
                                    preselectedClientId:
                                    client.id,
                                  ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 12),

                      _actionButton(
                        context: context,
                        icon: Icons.menu_book_outlined,
                        label: 'View Ledger',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LedgerScreen(
                                preselectedClientId:
                                client.id,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // DELETE CLIENT
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showDeleteConfirmationDialog(
                    context,
                    ref,
                    client,
                  ),
              icon: const Icon(
                Icons.delete_forever,
              ),
              label: const Text(
                'Delete Client',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 15,
                ),
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                minimumSize:
                const Size.fromHeight(50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}