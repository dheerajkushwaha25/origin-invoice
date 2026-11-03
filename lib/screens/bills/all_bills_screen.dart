import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/screens/invoices/invoice_form_screen.dart';
import 'package:ezinvoice/screens/invoices/invoice_preview_screen.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:intl/intl.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Invoice> _filteredInvoices = [];

  String _timeFilter = 'all';
  DateTime? _customStart;
  DateTime? _customEnd;
  String _amountFilter = 'all';
  double _minAmount = 0;
  double _maxAmount = 0;
  bool _filterByClient = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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

  void _onSearchChanged() => _applyFilters();

  void _enterSelectionMode(String invoiceNumber) {
    setState(() { _isSelectionMode = true; _selectedIds.add(invoiceNumber); });
  }

  void _exitSelectionMode() {
    setState(() { _isSelectionMode = false; _selectedIds.clear(); });
  }

  void _toggleSelection(String invoiceNumber) {
    setState(() {
      if (_selectedIds.contains(invoiceNumber)) {
        _selectedIds.remove(invoiceNumber);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(invoiceNumber);
      }
    });
  }

  void _selectAll() => setState(() => _selectedIds.addAll(_filteredInvoices.map((i) => i.invoiceNumber)));

  void _showBulkDeleteConfirm() {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Invoices'),
        content: Text('Delete $count invoice${count > 1 ? 's' : ''}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async { Navigator.of(dialogContext).pop(); await _bulkDelete(); },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkDelete() async {
    final notifier = ref.read(invoiceListProvider.notifier);
    final idsToDelete = Set<String>.from(_selectedIds);
    final count = idsToDelete.length;

    // Optimistic UI — remove from list instantly
    setState(() {
      _filteredInvoices.removeWhere((i) => idsToDelete.contains(i.invoiceNumber));
    });
    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Deleted $count invoice${count > 1 ? 's' : ''} successfully'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    }

    // Delete from Firestore in background
    for (final invoiceNumber in idsToDelete) {
      try { await notifier.deleteInvoice(invoiceNumber); } catch (_) {}
    }
  }

  List<Invoice> _applyFilters() {
    final allInvoices = ref.read(invoiceListProvider).value ?? [];
    final allClients = ref.read(clientListProvider).value ?? [];
    final sortKey = ref.read(invoiceSortKeyProvider);
    final query = _searchController.text.toLowerCase().trim();
    List<Invoice> result = List.of(allInvoices);

    if (query.isNotEmpty) {
      final queryClean = query.replaceAll(',', '').replaceAll('.', '').replaceAll('₹', '').trim();
      result = result.where((invoice) {
        if (invoice.invoiceNumber.toLowerCase().contains(query)) return true;
        final client = allClients.firstWhere((c) => c.id == invoice.clientId, orElse: () => const Client(id: '', businessName: ''));
        if (client.businessName.toLowerCase().contains(query)) return true;
        if (queryClean.isNotEmpty) {
          final amountClean = invoice.grandTotal.toStringAsFixed(2).replaceAll(',', '').replaceAll('.', '');
          if (amountClean.contains(queryClean)) return true;
        }
        return false;
      }).toList();
    }

    if (_filterByClient) {
      result.sort((a, b) {
        final cA = allClients.firstWhere((c) => c.id == a.clientId, orElse: () => const Client(id: '', businessName: '')).businessName;
        final cB = allClients.firstWhere((c) => c.id == b.clientId, orElse: () => const Client(id: '', businessName: '')).businessName;
        return cA.compareTo(cB);
      });
      setState(() => _filteredInvoices = result);
      return result;
    }

    final now = DateTime.now();
    if (_timeFilter == 'week') {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      result = result.where((i) => i.invoiceDate.isAfter(weekStart.subtract(const Duration(days: 1)))).toList();
    } else if (_timeFilter == 'month') {
      result = result.where((i) => i.invoiceDate.month == now.month && i.invoiceDate.year == now.year).toList();
    } else if (_timeFilter == 'year') {
      result = result.where((i) => i.invoiceDate.year == now.year).toList();
    } else if (_timeFilter == 'custom' && _customStart != null && _customEnd != null) {
      result = result.where((i) =>
      i.invoiceDate.isAfter(_customStart!.subtract(const Duration(days: 1))) &&
          i.invoiceDate.isBefore(_customEnd!.add(const Duration(days: 1)))).toList();
    }

    if (_amountFilter == 'above') result = result.where((i) => i.grandTotal > 10000).toList();
    else if (_amountFilter == 'below') result = result.where((i) => i.grandTotal < 10000).toList();
    else if (_amountFilter == 'custom' && _maxAmount > 0) result = result.where((i) => i.grandTotal >= _minAmount && i.grandTotal <= _maxAmount).toList();

    result = _performSorting(result, _amountFilter == 'high_low' ? 'amount_desc' : _amountFilter == 'low_high' ? 'amount_asc' : sortKey);
    setState(() => _filteredInvoices = result);
    return result;
  }

  List<Invoice> _performSorting(List<Invoice> list, String sortKey) {
    list.sort((a, b) {
      if (sortKey == 'amount_desc') return b.grandTotal.compareTo(a.grandTotal);
      if (sortKey == 'amount_asc') return a.grandTotal.compareTo(b.grandTotal);
      if (sortKey == 'date_asc') return a.invoiceDate.compareTo(b.invoiceDate);
      return b.invoiceDate.compareTo(a.invoiceDate);
    });
    return list;
  }

  void _showFilterSheet(BuildContext context) {
    final minController = TextEditingController(text: _minAmount > 0 ? _minAmount.toStringAsFixed(0) : '');
    final maxController = TextEditingController(text: _maxAmount > 0 ? _maxAmount.toStringAsFixed(0) : '');
    String tempTimeFilter = _timeFilter;
    String tempAmountFilter = _amountFilter;
    bool tempFilterByClient = _filterByClient;
    DateTime? tempCustomStart = _customStart;
    DateTime? tempCustomEnd = _customEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final dateFormat = DateFormat('dd MMM yyyy');
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24, top: 8),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () => setSheetState(() { tempTimeFilter = 'all'; tempAmountFilter = 'all'; tempFilterByClient = false; tempCustomStart = null; tempCustomEnd = null; minController.clear(); maxController.clear(); }),
                        child: const Text('Reset All'),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text('Client', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    FilterChip(label: const Text('Client Name (A-Z)'), selected: tempFilterByClient, onSelected: (val) => setSheetState(() => tempFilterByClient = val)),
                  ]),
                  const SizedBox(height: 16),
                  const Text('Time Period', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _filterChip('All', 'all', tempTimeFilter, (v) => setSheetState(() => tempTimeFilter = v)),
                    _filterChip('This Week', 'week', tempTimeFilter, (v) => setSheetState(() => tempTimeFilter = v)),
                    _filterChip('This Month', 'month', tempTimeFilter, (v) => setSheetState(() => tempTimeFilter = v)),
                    _filterChip('This Year', 'year', tempTimeFilter, (v) => setSheetState(() => tempTimeFilter = v)),
                    _filterChip('Custom Range', 'custom', tempTimeFilter, (v) => setSheetState(() => tempTimeFilter = v)),
                  ]),
                  if (tempTimeFilter == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(tempCustomStart == null ? 'Start Date' : dateFormat.format(tempCustomStart!)),
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: tempCustomStart ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                          if (picked != null) setSheetState(() => tempCustomStart = picked);
                        },
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(tempCustomEnd == null ? 'End Date' : dateFormat.format(tempCustomEnd!)),
                        onPressed: () async {
                          final picked = await showDatePicker(context: ctx, initialDate: tempCustomEnd ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
                          if (picked != null) setSheetState(() => tempCustomEnd = picked);
                        },
                      )),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  const Text('Amount', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _filterChip('All', 'all', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                    _filterChip('High to Low', 'high_low', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                    _filterChip('Low to High', 'low_high', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                    _filterChip('Above ₹10,000', 'above', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                    _filterChip('Below ₹10,000', 'below', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                    _filterChip('Custom Range', 'custom', tempAmountFilter, (v) => setSheetState(() => tempAmountFilter = v)),
                  ]),
                  if (tempAmountFilter == 'custom') ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min ₹', isDense: true))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: maxController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max ₹', isDense: true))),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _timeFilter = tempTimeFilter; _amountFilter = tempAmountFilter;
                          _filterByClient = tempFilterByClient; _customStart = tempCustomStart;
                          _customEnd = tempCustomEnd;
                          _minAmount = double.tryParse(minController.text.trim()) ?? 0;
                          _maxAmount = double.tryParse(maxController.text.trim()) ?? 0;
                        });
                        _applyFilters();
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('Apply Filters', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _filterChip(String label, String value, String current, Function(String) onSelected) {
    return FilterChip(label: Text(label), selected: current == value, onSelected: (_) => onSelected(value));
  }

  Future<void> _onRefresh() async {
    try {
      await Future.wait([ref.refresh(invoiceListProvider.future), ref.refresh(clientListProvider.future)]);
      if (mounted) setState(() => _filteredInvoices = []);
    } catch (_) {}
  }

  bool get _hasActiveFilters => _timeFilter != 'all' || _amountFilter != 'all' || _filterByClient;

  @override
  Widget build(BuildContext context) {
    final invoicesAsyncValue = ref.watch(invoiceListProvider);
    final sortKey = ref.watch(invoiceSortKeyProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    invoicesAsyncValue.whenData((invoices) {
      // Always sync filtered list when provider data changes
      // This ensures instant update when invoice is deleted from any screen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyFilters();
        }
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelectionMode) {
          _exitSelectionMode(); // exit selection mode on first back
        }
        // do nothing else — AppScaffold handles tab switching
      },
      child: Scaffold(
        appBar: _isSelectionMode
            ? AppBar(
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode),
          title: Text('${_selectedIds.length} selected'),
          actions: [
            TextButton(onPressed: _selectAll, child: const Text('Select All')),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Delete selected', onPressed: _selectedIds.isEmpty ? null : _showBulkDeleteConfirm),
          ],
        )
            : AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Search by name, invoice no, amount...', border: InputBorder.none),
            onChanged: (_) => _onSearchChanged(),
          )
              : const Text('All Bills'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) { _searchController.clear(); _applyFilters(); }
                });
              },
            ),
            if (!_isSearching)
              Stack(children: [
                IconButton(icon: const Icon(Icons.tune_outlined, size: 24), onPressed: () => _showFilterSheet(context)),
                if (_hasActiveFilters)
                  Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
              ]),
          ],
        ),
        body: invoicesAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: ${e.toString()}')),
          data: (invoices) {
            _performSorting(_filteredInvoices, sortKey);

            if (invoices.isEmpty && !_isSearching) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No bills yet. Tap "New Invoice" to start.')),
                ]),
              );
            }

            if (_filteredInvoices.isEmpty) {
              return Center(child: Text(
                _isSearching ? 'No results for "${_searchController.text}".' : 'No invoices match filters.',
                style: const TextStyle(color: Colors.grey),
              ));
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _filteredInvoices.length,
                itemBuilder: (context, index) {
                  final invoice = _filteredInvoices[index];
                  final dateString = dateFormat.format(invoice.invoiceDate);
                  final clientDetailAsync = ref.watch(clientDetailProvider(invoice.clientId));
                  final isSelected = _selectedIds.contains(invoice.invoiceNumber);

                  return clientDetailAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (client) {
                      final clientName = client?.businessName ?? 'Client Not Found';
                      String itemInfo = '';
                      if (invoice.items.isNotEmpty) {
                        final desc = invoice.items[0]['description'] ?? '';
                        final remaining = invoice.items.length - 1;
                        itemInfo = remaining > 0 ? '$desc (+$remaining more)' : desc;
                      }
                      final query = _searchController.text.trim();

                      // ── Darker colour for invoice # and date ──────────
                      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
                      final metaStyle = TextStyle(fontSize: 12, color: isDarkMode ? const Color(0xFFAAAAAA) : const Color(0xFF444444));
                      final metaIconColor = isDarkMode ? const Color(0xFFAAAAAA) : const Color(0xFF444444);

                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      return Card(
                        color: isSelected
                            ? Colors.red.withValues(alpha: 0.08)
                            : isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
                        ),
                        elevation: isDark ? 0 : 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isSelectionMode
                              ? () => _toggleSelection(invoice.invoiceNumber)
                              : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoiceNumber: invoice.invoiceNumber))),
                          onLongPress: _isSelectionMode ? null : () => _enterSelectionMode(invoice.invoiceNumber),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                // ── Checkbox (selection mode) ──────────────
                                if (_isSelectionMode) ...[
                                  Checkbox(value: isSelected, activeColor: Colors.red, onChanged: (_) => _toggleSelection(invoice.invoiceNumber)),
                                  const SizedBox(width: 4),
                                ],

                                // ── Content ────────────────────────────────
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Client name
                                      _highlightText(clientName, query, baseStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                                      const SizedBox(height: 4),

                                      // ── Invoice # and Date on same line ──
                                      Row(
                                        children: [
                                          Icon(Icons.receipt_outlined, size: 13, color: metaIconColor),
                                          const SizedBox(width: 4),
                                          _highlightText('#${invoice.invoiceNumber}', query, baseStyle: metaStyle),
                                          const SizedBox(width: 12),
                                          Icon(Icons.calendar_today_outlined, size: 12, color: metaIconColor),
                                          const SizedBox(width: 4),
                                          Text(dateString, style: metaStyle),
                                        ],
                                      ),

                                      // Item info
                                      if (itemInfo.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(itemInfo, style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFAAAAAA) : const Color(0xFF444444)), overflow: TextOverflow.ellipsis),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // ── Amount ─────────────────────────────────
                                _highlightAmount(_currency.format(invoice.grandTotal), query),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InvoiceFormScreen(invoiceData: null))),
          icon: const Icon(Icons.add_circle),
          label: const Text('New Invoice'),
        ),
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
          TextSpan(text: text.substring(index, index + query.length), style: (baseStyle ?? const TextStyle()).copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFFC363B))),
          if (index + query.length < text.length) TextSpan(text: text.substring(index + query.length), style: baseStyle),
        ],
      ),
    );
  }

  Widget _highlightAmount(String amountStr, String query) {
    const baseStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1877F2));
    if (query.isEmpty) return Text(amountStr, style: baseStyle);
    final queryClean = query.replaceAll(',', '').replaceAll('.', '').replaceAll('₹', '').trim();
    if (queryClean.isEmpty) return Text(amountStr, style: baseStyle);
    final digitsOnly = amountStr.replaceAll(RegExp(r'[^0-9]'), '');
    final matchIndex = digitsOnly.indexOf(queryClean);
    if (matchIndex == -1) return Text(amountStr, style: baseStyle);
    int digitCount = 0;
    int startPos = -1, endPos = -1;
    for (int i = 0; i < amountStr.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(amountStr[i])) {
        if (digitCount == matchIndex) startPos = i;
        if (digitCount == matchIndex + queryClean.length - 1) { endPos = i + 1; break; }
        digitCount++;
      }
    }
    if (startPos == -1 || endPos == -1) return Text(amountStr, style: baseStyle);
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.merge(baseStyle),
        children: [
          if (startPos > 0) TextSpan(text: amountStr.substring(0, startPos), style: baseStyle),
          TextSpan(text: amountStr.substring(startPos, endPos), style: baseStyle.copyWith(color: const Color(0xFFFC363B))),
          if (endPos < amountStr.length) TextSpan(text: amountStr.substring(endPos), style: baseStyle),
        ],
      ),
    );
  }
}
