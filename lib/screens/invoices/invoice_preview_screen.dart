// lib/screens/invoices/invoice_preview_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/services/amazon_style_invoice_service.dart';
import 'package:ezinvoice/screens/invoices/invoice_form_screen.dart';

class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final String invoiceNumber;
  const InvoicePreviewScreen({super.key, required this.invoiceNumber});

  @override
  ConsumerState<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  Uint8List? _pdfBytes;
  bool _isLoading = true;
  bool _clientMissing = false;
  Invoice? _currentInvoice;
  String? _clientName;

  @override
  void initState() {
    super.initState();
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    setState(() { _isLoading = true; _clientMissing = false; });

    try {
      final invoices = await ref.read(invoiceListProvider.future);
      final invoice = invoices.firstWhere(
              (inv) => inv.invoiceNumber == widget.invoiceNumber);

      setState(() => _currentInvoice = invoice);

      final company = ref.read(activeCompanyProvider);
      final client = await ref.read(clientDetailProvider(invoice.clientId).future);

      if (client == null) {
        setState(() { _isLoading = false; _clientMissing = true; });
        return;
      }

      // ✅ Store client name for display
      setState(() => _clientName = client.businessName);

      final double subtotal   = invoice.subtotal;
      final double cgstTotal  = invoice.cgstTotal;
      final double sgstTotal  = invoice.sgstTotal;
      final double grandTotal = invoice.grandTotal;
      final double base       = grandTotal - cgstTotal - sgstTotal;
      final double discountAmount = (subtotal - base).clamp(0.0, subtotal);
      final double cgstPercent = base > 0 ? (cgstTotal / base) * 100.0 : 0.0;
      final double sgstPercent = base > 0 ? (sgstTotal / base) * 100.0 : 0.0;

      final pdfBytes = await AmazonStyleInvoiceService().generatePdf(
        invoice, company, client,
        transportMode:  invoice.transportMode,
        vehicleNumber:  invoice.vehicleNumber,
        discountAmount: discountAmount,
        cgstPercent:    cgstPercent,
        sgstPercent:    sgstPercent,
      );

      setState(() { _pdfBytes = pdfBytes; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _duplicateInvoice() async {
    if (_currentInvoice == null) return;
    try {
      final nextNumber = await ref.read(nextInvoiceNumberProvider('').future);
      final duplicatedInvoice = Invoice(
        id:            DateTime.now().millisecondsSinceEpoch.toString(),
        companyId:     _currentInvoice!.companyId,
        clientId:      _currentInvoice!.clientId,
        invoiceNumber: nextNumber['sequential']!,
        invoiceDate:   DateTime.now(),
        dueDate:       DateTime.now(),
        subtotal:      _currentInvoice!.subtotal,
        cgstTotal:     _currentInvoice!.cgstTotal,
        sgstTotal:     _currentInvoice!.sgstTotal,
        grandTotal:    _currentInvoice!.grandTotal,
        notes:         _currentInvoice!.notes,
        status:        InvoiceStatus.pending,
        items:         List.from(_currentInvoice!.items),
        poNumber:      _currentInvoice!.poNumber,
        poDate:        _currentInvoice!.poDate,
        transportMode: _currentInvoice!.transportMode,
        vehicleNumber: _currentInvoice!.vehicleNumber,
        challanNumber: _currentInvoice!.challanNumber,
        challanDate:   _currentInvoice!.challanDate,
        termsAndConditions: _currentInvoice!.termsAndConditions,
      );

      await ref.read(invoiceListProvider.notifier).addInvoice(duplicatedInvoice);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Invoice duplicated as ${duplicatedInvoice.invoiceNumber}'),
          backgroundColor: Colors.green,
        ));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error duplicating invoice: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printPdf() async {
    if (_pdfBytes == null) return;
    await Printing.layoutPdf(
      onLayout: (format) async => _pdfBytes!,
      name: 'Invoice_${widget.invoiceNumber}.pdf',
    );
  }

  Future<void> _sharePdf() async {
    if (_pdfBytes == null) return;
    try {
      final output = await getTemporaryDirectory();
      final file   = File('${output.path}/Invoice_${widget.invoiceNumber}.pdf');
      await file.writeAsBytes(_pdfBytes!);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Invoice ${widget.invoiceNumber}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteInvoice() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Invoice?'),
        content: Text('Delete invoice ${widget.invoiceNumber}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirm == true && _currentInvoice != null && _currentInvoice!.id != null) {
      ref.read(invoiceListProvider.notifier).deleteInvoice(_currentInvoice!.id!);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted')));
      }
    }
  }

  void _editInvoice() {
    if (_currentInvoice != null && mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => InvoiceFormScreen(invoiceData: _currentInvoice)));
    }
  }

  void _openFullscreenPdf() {
    if (_pdfBytes == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text(widget.invoiceNumber),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Colors.black,
        ),
        body: PdfPreview(
          build: (format) => _pdfBytes!,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          useActions: false,
          actions: const [],
          pdfFileName: 'Invoice_${widget.invoiceNumber}.pdf',
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentInvoice == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.invoiceNumber)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.invoiceNumber),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // PDF Preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _clientMissing
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      const Text('Client not found',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        'The client linked to this invoice has been deleted.\nYou can still edit or delete this invoice.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
                  : _pdfBytes == null
                  ? const Center(child: Text('Failed to load PDF'))
                  : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: _openFullscreenPdf,
                  child: PdfPreview(
                    build: (format) => _pdfBytes!,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    useActions: false,
                    actions: const [],
                    scrollViewDecoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Section
          Container(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Grand total
                Text(
                  currencyFormat.format(_currentInvoice!.grandTotal),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),

                // ✅ Client name (visible) + date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _clientMissing
                            ? 'Client deleted'
                            : (_clientName ?? ''),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                          fontStyle: _clientMissing
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yyyy').format(_currentInvoice!.invoiceDate),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Share button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: _clientMissing ? null : _sharePdf,
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Share Invoice',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ActionButton(
                      icon: Icons.print,
                      label: 'Print',
                      onTap: _clientMissing ? () {} : _printPdf,
                      color: _clientMissing ? Colors.grey[300] : null,
                    ),
                    _ActionButton(
                      icon: Icons.file_copy,
                      label: 'Duplicate',
                      onTap: _clientMissing ? () {} : _duplicateInvoice,
                      color: _clientMissing ? Colors.grey[300] : null,
                    ),
                    _ActionButton(
                      icon: Icons.edit,
                      label: 'Edit',
                      onTap: _clientMissing ? () {} : _editInvoice,
                      color: _clientMissing ? Colors.grey[300] : null,
                    ),
                    _ActionButton(
                      icon: Icons.delete,
                      label: 'Delete',
                      onTap: _deleteInvoice,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28,
              color: color ?? (isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 12,
                  color: color ?? (isDark ? Colors.white70 : Colors.black87))),
        ],
      ),
    );
  }
}
