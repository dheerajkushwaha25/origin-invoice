import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/screens/clients/client_detail_screen.dart';
import 'package:ezinvoice/screens/invoices/invoice_preview_screen.dart';

class UniversalSearchScreen extends ConsumerStatefulWidget {
  const UniversalSearchScreen({super.key});

  @override
  ConsumerState<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends ConsumerState<UniversalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _clientResults = [];
  List<Invoice> _invoiceResults = [];
  String _currentQuery = "";

  final _currency = NumberFormat.currency(locale: "en_IN", symbol: "₹");

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() { _currentQuery = ""; _clientResults = []; _invoiceResults = []; });
      return;
    }

    final List<Invoice> allInvoices = ref.read(invoiceListProvider).valueOrNull ?? [];
    final List<Client> allClients = ref.read(clientListProvider).valueOrNull ?? [];
    final clientMap = {for (final c in allClients) c.id: c};

    final clientResults = allClients.where((client) {
      return client.businessName.toLowerCase().contains(query) ||
          (client.gstNumber?.toLowerCase().contains(query) ?? false);
    }).toList();

    final invoiceResults = allInvoices.where((invoice) {
      if (invoice.invoiceNumber.toLowerCase().contains(query)) return true;
      final clientName = clientMap[invoice.clientId]?.businessName.toLowerCase() ?? "";
      if (clientName.contains(query)) return true;
      final amountClean = invoice.grandTotal.toStringAsFixed(2).replaceAll(",", "").replaceAll(".", "");
      final queryClean = query.replaceAll(",", "").replaceAll(".", "").replaceAll("₹", "").trim();
      if (queryClean.isNotEmpty && amountClean.contains(queryClean)) return true;
      return false;
    }).toList();

    setState(() {
      _currentQuery = query;
      _clientResults = clientResults;
      _invoiceResults = invoiceResults;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Inline AppBar search — same style as bills screen ──────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name, invoice no, amount...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(), // ← closes screen, same as bills ×
          ),
        ],
      ),
      body: _currentQuery.isEmpty
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              "Search by client name, invoice\nnumber, GST or amount",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : _buildResultsList(context),
    );
  }

  Widget _buildResultsList(BuildContext context) {
    final hasResults = _clientResults.isNotEmpty || _invoiceResults.isNotEmpty;
    final clientMap = {
      for (final c in (ref.read(clientListProvider).valueOrNull ?? [])) c.id: c
    };

    if (!hasResults) {
      return Center(
        child: Text('No results for "$_currentQuery"',
            style: const TextStyle(color: Colors.grey)),
      );
    }

    return ListView(
      children: [
        if (_clientResults.isNotEmpty) ...[
          _sectionHeader("Clients (${_clientResults.length})"),
          ..._clientResults.map((client) => ListTile(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ClientDetailScreen(clientName: client.businessName))),
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                client.businessName[0].toUpperCase(),
                style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: _highlightText(client.businessName, _currentQuery),
            subtitle: _highlightText(
              client.gstNumber?.isNotEmpty == true ? "GST: ${client.gstNumber!}" : "Client",
              _currentQuery,
              baseStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          )),
        ],
        if (_invoiceResults.isNotEmpty) ...[
          _sectionHeader("Invoices (${_invoiceResults.length})"),
          ..._invoiceResults.map((invoice) {
            final clientName = clientMap[invoice.clientId]?.businessName ?? "Unknown";
            final amountStr = _currency.format(invoice.grandTotal);
            return ListTile(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => InvoicePreviewScreen(invoiceNumber: invoice.invoiceNumber))),
              leading: const CircleAvatar(child: Icon(Icons.receipt_long, size: 18)),
              title: _highlightText("Invoice #${invoice.invoiceNumber}", _currentQuery),
              subtitle: _highlightText(clientName, _currentQuery),
              trailing: _highlightAmount(amountStr, _currentQuery),
            );
          }),
        ],
      ],
    );
  }

  Widget _highlightAmount(String amountStr, String query) {
    const baseStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent);
    final queryClean = query.replaceAll(",", "").replaceAll(".", "").replaceAll("₹", "").trim();
    if (queryClean.isEmpty) return Text(amountStr, style: baseStyle);
    final digitsOnly = amountStr.replaceAll(RegExp(r"[^0-9]"), "");
    final matchIndex = digitsOnly.indexOf(queryClean);
    if (matchIndex == -1) return Text(amountStr, style: baseStyle);
    int digitCount = 0;
    int startPos = -1, endPos = -1;
    for (int i = 0; i < amountStr.length; i++) {
      if (RegExp(r"[0-9]").hasMatch(amountStr[i])) {
        if (digitCount == matchIndex) startPos = i;
        if (digitCount == matchIndex + queryClean.length - 1) { endPos = i + 1; break; }
        digitCount++;
      }
    }
    if (startPos == -1 || endPos == -1) return Text(amountStr, style: baseStyle);
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (startPos > 0) TextSpan(text: amountStr.substring(0, startPos)),
          TextSpan(text: amountStr.substring(startPos, endPos), style: baseStyle.copyWith(color: const Color(0xFFFC363B))),
          if (endPos < amountStr.length) TextSpan(text: amountStr.substring(endPos)),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _highlightText(String text, String query, {TextStyle? baseStyle}) {
    if (query.isEmpty) return Text(text, style: baseStyle);
    final index = text.toLowerCase().indexOf(query.toLowerCase());
    if (index == -1) return Text(text, style: baseStyle);
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.merge(baseStyle),
        children: [
          if (index > 0) TextSpan(text: text.substring(0, index), style: baseStyle),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: (baseStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFFC363B)),
          ),
          if (index + query.length < text.length) TextSpan(text: text.substring(index + query.length), style: baseStyle),
        ],
      ),
    );
  }
}
