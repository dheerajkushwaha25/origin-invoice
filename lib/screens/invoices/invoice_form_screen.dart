// lib/screens/invoices/invoice_form_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/screens/invoices/item_detail_input_page.dart';
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/services/amazon_style_invoice_service.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

enum NumberingMode { serial, manual }
enum DiscountType { percent, amount }

class InvoiceFormScreen extends ConsumerStatefulWidget {
  final Invoice? invoiceData;
  const InvoiceFormScreen({super.key, this.invoiceData});

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  Client? _selectedClient;
  late List<Map<String, dynamic>> _invoiceItems;

  late TextEditingController _invoiceNumberController;
  final _poNumberController       = TextEditingController();
  final _transportModeController  = TextEditingController();
  final _vehicleNumberController  = TextEditingController();
  final _cgstOverallController    = TextEditingController();
  final _sgstOverallController    = TextEditingController();
  final _challanNumberController  = TextEditingController();
  final _notesController          = TextEditingController();
  final _termsController          = TextEditingController();

  DiscountType _discountType = DiscountType.percent;
  final TextEditingController _discountController = TextEditingController(text: '0');

  bool _showDiscountInput = false;
  bool _showChallan   = false; // inside Invoice Details
  bool _showLogistics = false; // separate card below items
  bool _showNotes     = false; // separate card below items
  bool _showTerms     = false; // separate card below items
  bool _isSaving      = false;

  DateTime _invoiceDate = DateTime.now();
  DateTime? _poDate;
  DateTime? _challanDate;

  final _formKey = GlobalKey<FormState>();
  NumberingMode _numberingMode = NumberingMode.serial;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.invoiceData != null;
    final invoice   = widget.invoiceData;

    if (isEditing) {
      _invoiceItems  = List.from(invoice!.items);
      _invoiceNumberController = TextEditingController(text: invoice.invoiceNumber);
      _invoiceDate   = invoice.invoiceDate;
      _numberingMode = NumberingMode.manual;
      _poNumberController.text      = invoice.poNumber ?? '';
      _poDate                       = invoice.poDate;
      _transportModeController.text = invoice.transportMode ?? '';
      _vehicleNumberController.text = invoice.vehicleNumber ?? '';
      _challanNumberController.text = invoice.challanNumber ?? '';
      _challanDate                  = invoice.challanDate;
      _notesController.text         = invoice.notes;
      _termsController.text         = invoice.termsAndConditions ?? '';

      _showChallan   = invoice.challanNumber != null || invoice.challanDate != null;
      _showLogistics = invoice.transportMode != null || invoice.vehicleNumber != null;
      _showNotes     = invoice.notes.isNotEmpty;
      _showTerms     = (invoice.termsAndConditions ?? '').isNotEmpty;

      final double subtotal    = invoice.subtotal;
      final double cgstTotal   = invoice.cgstTotal;
      final double sgstTotal   = invoice.sgstTotal;
      final double taxes       = cgstTotal + sgstTotal;
      final double grand       = invoice.grandTotal;
      final double base        = (grand - taxes).clamp(0.0, double.infinity);
      final double discountAmt = (subtotal - base).clamp(0.0, subtotal);
      final double cgstPct     = base > 0 ? (cgstTotal / base) * 100.0 : 0.0;
      final double sgstPct     = base > 0 ? (sgstTotal / base) * 100.0 : 0.0;

      _discountType = DiscountType.amount;
      _discountController.text    = discountAmt.toStringAsFixed(2);
      _cgstOverallController.text = cgstPct.toStringAsFixed(2);
      _sgstOverallController.text = sgstPct.toStringAsFixed(2);
      _showDiscountInput          = discountAmt > 0;

      final clients = ref.read(clientListProvider).valueOrNull ?? [];
      final match   = clients.firstWhere((c) => c.id == invoice.clientId,
          orElse: () => null as Client);
      if (match != null) _selectedClient = match;
    } else {
      _invoiceItems = [];
      _invoiceNumberController = TextEditingController(text: 'Loading...');
      _numberingMode = NumberingMode.serial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final defaultCgst = ref.read(defaultCgstProvider).valueOrNull ?? 0.0;
        final defaultSgst = ref.read(defaultSgstProvider).valueOrNull ?? 0.0;
        _cgstOverallController.text = defaultCgst > 0 ? defaultCgst.toString() : '0';
        _sgstOverallController.text = defaultSgst > 0 ? defaultSgst.toString() : '0';
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _poNumberController.dispose();
    _discountController.dispose();
    _transportModeController.dispose();
    _vehicleNumberController.dispose();
    _cgstOverallController.dispose();
    _sgstOverallController.dispose();
    _challanNumberController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  int _extractNumericQty(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    final n = v.toString().trim().replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(n) ?? 1;
  }

  Future<void> _selectDate(DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  void _toggleNumberingMode(String seq) {
    setState(() {
      if (_numberingMode == NumberingMode.serial) {
        _numberingMode = NumberingMode.manual;
      } else {
        _numberingMode = NumberingMode.serial;
        _invoiceNumberController.text = seq;
      }
    });
  }

  // ✅ ⋮ menu — only Logistics, Notes, Terms
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add optional sections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Logistics
              SwitchListTile(
                title: const Text('Transport / Logistics'),
                value: _showLogistics,
                activeColor: Colors.blue,
                onChanged: (val) {
                  setSheet(() {});
                  setState(() {
                    _showLogistics = val;
                    if (!val) { _transportModeController.clear(); _vehicleNumberController.clear(); }
                  });
                },
              ),
              // Notes
              SwitchListTile(
                title: const Text('Notes'),
                value: _showNotes,
                activeColor: Colors.blue,
                onChanged: (val) {
                  setSheet(() {});
                  setState(() {
                    _showNotes = val;
                    if (!val) _notesController.clear();
                  });
                },
              ),
              // Terms & Conditions
              SwitchListTile(
                title: const Text('Terms & Conditions'),
                value: _showTerms,
                activeColor: Colors.blue,
                onChanged: (val) {
                  setSheet(() {});
                  setState(() {
                    _showTerms = val;
                    if (!val) _termsController.clear();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddItem() async {
    final newItem = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => const ItemDetailInputPage(), fullscreenDialog: true),
    );
    if (newItem != null) {
      if (!newItem.containsKey('quantity_numeric')) {
        final qty = newItem['quantity'].toString();
        newItem['quantity_numeric'] =
            int.tryParse(qty.replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
      }
      setState(() => _invoiceItems.add(newItem));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item ${newItem['description']} added.')));
    }
  }

  double _parsedDiscountAmount(double subtotal) {
    if (_discountType == DiscountType.amount) {
      final amt = double.tryParse(_discountController.text.trim().replaceAll(',', '')) ?? 0;
      return amt.clamp(0, subtotal);
    } else {
      final pct = double.tryParse(_discountController.text.trim().replaceAll(',', '.')) ?? 0;
      return (pct.clamp(0, 100) / 100.0) * subtotal;
    }
  }

  double _parsedDiscountPercent(double subtotal) {
    if (_discountType == DiscountType.amount) {
      final amt = _parsedDiscountAmount(subtotal);
      return subtotal == 0 ? 0 : (amt / subtotal) * 100.0;
    } else {
      return (double.tryParse(_discountController.text.trim().replaceAll(',', '.')) ?? 0).clamp(0, 100);
    }
  }

  void _saveAndGenerate() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null || _invoiceItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a client and add at least one item.')));
      return;
    }
    setState(() => _isSaving = true);

    double subtotal = 0.0;
    for (var item in _invoiceItems) {
      subtotal += ((item['rate'] ?? 0.0) * 1.0) * _extractNumericQty(item['quantity']);
    }

    final double cgstPct  = (double.tryParse(_cgstOverallController.text.trim()) ?? 0).clamp(0.0, 100.0).toDouble();
    final double sgstPct  = (double.tryParse(_sgstOverallController.text.trim()) ?? 0).clamp(0.0, 100.0).toDouble();
    final discountAmt     = _parsedDiscountAmount(subtotal);
    final discountPct     = _parsedDiscountPercent(subtotal);
    final base            = subtotal - discountAmt;
    final cgstTotal       = base * (cgstPct / 100.0);
    final sgstTotal       = base * (sgstPct / 100.0);
    final grandTotal      = base + cgstTotal + sgstTotal;

    final activeCompany  = ref.read(activeCompanyProvider);
    final selectedClient = _selectedClient!;

    final finalInvoice = Invoice(
      id:                 widget.invoiceData?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      companyId:          activeCompany.id,
      clientId:           selectedClient.id,
      invoiceNumber:      _invoiceNumberController.text,
      invoiceDate:        _invoiceDate,
      dueDate:            DateTime.now(),
      subtotal:           subtotal,
      cgstTotal:          cgstTotal,
      sgstTotal:          sgstTotal,
      grandTotal:         grandTotal,
      notes:              _notesController.text.trim(),
      termsAndConditions: _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
      status:             InvoiceStatus.pending,
      items:              _invoiceItems,
      poNumber:           _poNumberController.text.trim().isEmpty ? null : _poNumberController.text.trim(),
      poDate:             _poDate,
      transportMode:      _transportModeController.text.trim().isEmpty ? null : _transportModeController.text.trim(),
      vehicleNumber:      _vehicleNumberController.text.trim().isEmpty ? null : _vehicleNumberController.text.trim(),
      challanNumber:      _challanNumberController.text.trim().isEmpty ? null : _challanNumberController.text.trim(),
      challanDate:        _challanDate,
    );

    try {
      await ref.read(invoiceListProvider.notifier).addInvoice(finalInvoice);
      final pdfBytes = await AmazonStyleInvoiceService().generatePdf(
        finalInvoice, activeCompany, selectedClient,
        transportMode:   finalInvoice.transportMode,
        vehicleNumber:   finalInvoice.vehicleNumber,
        discountPercent: discountPct,
        discountAmount:  discountAmt,
        cgstPercent:     cgstPct,
        sgstPercent:     sgstPct,
      );
      if (mounted) {
        await Printing.layoutPdf(
            onLayout: (_) async => pdfBytes,
            name: 'Invoice_${finalInvoice.invoiceNumber}.pdf');
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Section card ──────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
    VoidCallback? onMoreTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C)) : BorderSide.none,
      ),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (onMoreTap != null)
                  InkWell(
                    onTap: onMoreTap,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.more_vert, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  // ── Optional section card (Logistics / Notes / Terms) ────────────────────
  Widget _optionalCard({
    required String title,
    required List<Widget> children,
    required VoidCallback onClose,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C)) : BorderSide.none,
      ),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing          = widget.invoiceData != null;
    final clientsAsync       = ref.watch(clientListProvider);
    final clients            = clientsAsync.value ?? [];
    final invoiceNumberAsync = ref.watch(nextInvoiceNumberProvider(''));
    final dateFormat         = DateFormat('dd/MM/yyyy');
    final currencyFormat     = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final bottomPadding      = MediaQuery.of(context).viewInsets.bottom;

    double subtotal = 0.0;
    for (var item in _invoiceItems) {
      subtotal += ((item['rate'] ?? 0.0) * 1.0) * _extractNumericQty(item['quantity']);
    }

    String sequentialNumber = 'Loading...';
    if (!isEditing && _numberingMode == NumberingMode.serial && invoiceNumberAsync.hasValue) {
      sequentialNumber = invoiceNumberAsync.value!['sequential']!;
      if (_invoiceNumberController.text == 'Loading...') {
        WidgetsBinding.instance.addPostFrameCallback(
                (_) => _invoiceNumberController.text = sequentialNumber);
      }
    }

    final clientToRestoreId = widget.invoiceData?.clientId;
    if (isEditing && _selectedClient == null && clients.isNotEmpty && clientToRestoreId != null) {
      final match = clients.firstWhere((c) => c.id == clientToRestoreId,
          orElse: () => null as Client);
      if (match != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => setState(() => _selectedClient = match));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? 'Edit Invoice ${widget.invoiceData!.invoiceNumber}'
            : 'Create New Invoice'),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Error: Could not load clients.')),
        data: (clients) => Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
            children: [

              // ── Invoice Details ──────────────────────────────────────────
              _sectionCard(
                title: 'Invoice Details',
                onMoreTap: () => _showOptionsMenu(context),
                children: [
                  // Invoice No + Date
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _invoiceNumberController,
                        decoration: InputDecoration(
                          labelText: 'Invoice Number *',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _numberingMode == NumberingMode.serial ? Icons.edit : Icons.sync,
                              size: 20,
                              color: _numberingMode == NumberingMode.serial ? Colors.grey : Colors.blue,
                            ),
                            onPressed: () => _toggleNumberingMode(sequentialNumber),
                          ),
                        ),
                        readOnly: _numberingMode == NumberingMode.serial && !isEditing,
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(_invoiceDate, (d) => _invoiceDate = d),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Invoice Date *'),
                          child: Text(dateFormat.format(_invoiceDate)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // PO Number + PO Date
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _poNumberController,
                        decoration: const InputDecoration(labelText: 'PO Number'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(_poDate, (d) => _poDate = d),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'PO Date',
                            suffixIcon: _poDate != null
                                ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () => setState(() => _poDate = null))
                                : null,
                          ),
                          child: Text(
                            _poDate == null ? 'Select PO Date' : dateFormat.format(_poDate!),
                            style: TextStyle(color: _poDate == null ? Colors.grey : null),
                          ),
                        ),
                      ),
                    ),
                  ]),

                  // ── Challan toggle (stays inside Invoice Details) ────────
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Add Challan Details?',
                          style: TextStyle(fontSize: 14)),
                      Switch(
                        value: _showChallan,
                        activeColor: Colors.blue,
                        onChanged: (val) => setState(() {
                          _showChallan = val;
                          if (!val) { _challanNumberController.clear(); _challanDate = null; }
                        }),
                      ),
                    ],
                  ),
                  if (_showChallan) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _challanNumberController,
                          decoration: const InputDecoration(labelText: 'Challan No'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectDate(_challanDate, (d) => _challanDate = d),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Challan Date',
                              suffixIcon: _challanDate != null
                                  ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => setState(() => _challanDate = null))
                                  : null,
                            ),
                            child: Text(
                              _challanDate == null ? 'Select Date' : dateFormat.format(_challanDate!),
                              style: TextStyle(color: _challanDate == null ? Colors.grey : null),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),

              // ── Client Details ───────────────────────────────────────────
              _sectionCard(
                title: 'Client Details',
                children: [
                  GestureDetector(
                    onTap: () => _showClientSearchSheet(clients),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF2A2A2A)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            _selectedClient?.businessName ?? 'Select Client *',
                            style: TextStyle(
                                fontSize: 16,
                                color: _selectedClient == null ? Colors.grey : null),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ]),
                    ),
                  ),
                ],
              ),

              // ── Items & Services ─────────────────────────────────────────
              _sectionCard(
                title: 'Items & Services',
                children: [
                  if (_invoiceItems.isEmpty)
                    const Center(child: Text('No items added yet.'))
                  else
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _invoiceItems.removeAt(oldIndex);
                          _invoiceItems.insert(newIndex, item);
                        });
                      },
                      children: _invoiceItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item  = entry.value;
                        final double rate     = (item['rate'] ?? 0.0) * 1.0;
                        final int    quantity = _extractNumericQty(item['quantity']);
                        return Card(
                          key: ValueKey(item.hashCode),
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E1E1E)
                              : Colors.white,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item['description'] ?? 'Item'),
                            subtitle: Text('Qty: ${item['quantity']} @ ${currencyFormat.format(rate)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(currencyFormat.format(rate * quantity),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() => _invoiceItems.removeAt(index));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Item removed')));
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              final edited = await Navigator.of(context)
                                  .push<Map<String, dynamic>>(MaterialPageRoute(
                                  builder: (_) => ItemDetailInputPage(existingItem: item),
                                  fullscreenDialog: true));
                              if (edited != null) {
                                if (!edited.containsKey('quantity_numeric')) {
                                  edited['quantity_numeric'] = int.tryParse(
                                      edited['quantity'].toString().replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
                                }
                                setState(() => _invoiceItems[index] = edited);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _navigateToAddItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Item'),
                  ),
                ],
              ),

              // ── Logistics card (below items, only if enabled) ────────────
              if (_showLogistics)
                _optionalCard(
                  title: 'Transport / Logistics',
                  onClose: () => setState(() {
                    _showLogistics = false;
                    _transportModeController.clear();
                    _vehicleNumberController.clear();
                  }),
                  children: [
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: _transportModeController,
                          decoration: const InputDecoration(
                              labelText: 'Transport Mode', hintText: 'e.g. Road/Rail/Air'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _vehicleNumberController,
                          decoration: const InputDecoration(
                              labelText: 'Vehicle Number', hintText: 'e.g. MH04AB1234'),
                        ),
                      ),
                    ]),
                  ],
                ),

              // ── Notes card (below items, only if enabled) ────────────────
              if (_showNotes)
                _optionalCard(
                  title: 'Notes',
                  onClose: () => setState(() {
                    _showNotes = false;
                    _notesController.clear();
                  }),
                  children: [
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'e.g. Thank you for your business!',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),

              // ── Terms card (below items, only if enabled) ────────────────
              if (_showTerms)
                _optionalCard(
                  title: 'Terms & Conditions',
                  onClose: () => setState(() {
                    _showTerms = false;
                    _termsController.clear();
                  }),
                  children: [
                    TextFormField(
                      controller: _termsController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Terms & Conditions',
                        hintText: 'e.g. Payment due within 30 days...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),

              // ── Summary ──────────────────────────────────────────────────
              _buildSummaryCard(subtotal: subtotal, currencyFormat: currencyFormat),

              // ── Save Button ──────────────────────────────────────────────
              ElevatedButton(
                onPressed: _isSaving ? null : _saveAndGenerate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Saving...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                )
                    : Text(
                  isEditing ? 'Update & Regenerate' : 'Save & Generate Invoice',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required double subtotal, required NumberFormat currencyFormat}) {
    final double cgstPct  = (double.tryParse(_cgstOverallController.text.trim()) ?? 0).clamp(0.0, 100.0).toDouble();
    final double sgstPct  = (double.tryParse(_sgstOverallController.text.trim()) ?? 0).clamp(0.0, 100.0).toDouble();
    final discountAmt     = _parsedDiscountAmount(subtotal);
    final discountPct     = subtotal == 0 ? 0 : (discountAmt / subtotal) * 100.0;
    final base            = subtotal - discountAmt;
    final cgstAmt         = base * (cgstPct / 100.0);
    final sgstAmt         = base * (sgstPct / 100.0);
    final grandTotal      = base + cgstAmt + sgstAmt;
    final hasDiscount     = discountAmt > 0.0001;
    final isDark          = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C)) : BorderSide.none,
      ),
      elevation: isDark ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(children: [
                  const Text('Discount', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  Switch(
                    value: _showDiscountInput,
                    onChanged: (val) => setState(() {
                      _showDiscountInput = val;
                      if (!val) _discountController.text = '0';
                    }),
                  ),
                ]),
              ],
            ),
            const SizedBox(height: 8),
            _row('Subtotal', currencyFormat.format(subtotal), bold: false),
            if (_showDiscountInput) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _discountType == DiscountType.amount ? 'Discount (Rs)' : 'Discount (%)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  prefixText: _discountType == DiscountType.amount ? '₹ ' : null,
                  suffixText: _discountType == DiscountType.percent ? '%' : null,
                  suffixIcon: PopupMenuButton<DiscountType>(
                    icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.black54),
                    onSelected: (t) => setState(() => _discountType = t),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: DiscountType.percent, child: Text('Percent (%)')),
                      PopupMenuItem(value: DiscountType.amount, child: Text('Amount (Rs)')),
                    ],
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (hasDiscount) ...[
              const SizedBox(height: 6),
              _row(
                _discountType == DiscountType.amount
                    ? 'Discount (Rs)'
                    : 'Discount (${discountPct.toStringAsFixed(2)}%)',
                '- ${currencyFormat.format(discountAmt)}',
                bold: false,
              ),
              _row('Taxable value after discount', currencyFormat.format(base), bold: false),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _cgstOverallController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'CGST (%)', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _sgstOverallController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'SGST (%)', isDense: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            _row('CGST (${cgstPct.toStringAsFixed(2)}%)', currencyFormat.format(cgstAmt), bold: false),
            _row('SGST (${sgstPct.toStringAsFixed(2)}%)', currencyFormat.format(sgstAmt), bold: false),
            const Divider(thickness: 2),
            _row('GRAND TOTAL', currencyFormat.format(grandTotal), bold: true),
          ],
        ),
      ),
    );
  }

  void _showClientSearchSheet(List<Client> clients) {
    final searchController = TextEditingController();
    List<Client> filtered = List.of(clients);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16, top: 8),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(children: [
              const Text('Select Client',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search clients',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        setSheet(() => filtered = List.of(clients));
                      })
                      : null,
                ),
                onChanged: (q) => setSheet(() => filtered = clients
                    .where((c) => c.businessName.toLowerCase().contains(q.toLowerCase().trim()))
                    .toList()),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No clients found'))
                    : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final c = filtered[i];
                    final isSelected = _selectedClient?.id == c.id;
                    return ListTile(
                      title: Text(c.businessName),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      tileColor: isSelected
                          ? Colors.green.withValues(alpha: 0.05)
                          : null,
                      onTap: () {
                        setState(() => _selectedClient = c);
                        Navigator.pop(sheetCtx);
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _row(String title, String value, {required bool bold}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(title, style: style), Text(value, style: style)],
      ),
    );
  }
}
