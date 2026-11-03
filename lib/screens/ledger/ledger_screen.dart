import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/models/payment.dart';

import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/payment_provider.dart';
import 'package:ezinvoice/providers/company_provider.dart';

import 'package:ezinvoice/services/ledger_pdf_service.dart';
import 'package:ezinvoice/services/ledger_excel_service.dart';

class LedgerScreen extends ConsumerStatefulWidget {
  final String? preselectedClientId;

  const LedgerScreen({
    super.key,
    this.preselectedClientId,
  });

  @override
  ConsumerState<LedgerScreen> createState() =>
      _LedgerScreenState();
}

class _LedgerScreenState
    extends ConsumerState<LedgerScreen> {
  String? _selectedClientId;

  DateTime _fromDate = DateTime(
    DateTime.now().year,
    4,
    1,
  );

  DateTime _toDate = DateTime.now();

  bool _loading = false;
  bool _hasGenerated = false;

  List<LedgerEntry> _entries = [];

  double _openingBalance = 0;
  double _totalDebit = 0;
  double _totalCredit = 0;
  double _closingBalance = 0;

  final DateFormat _dateFormat =
  DateFormat('dd MMM yyyy');

  final NumberFormat _currency =
  NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
  );

  @override
  void initState() {
    super.initState();

    _selectedClientId =
        widget.preselectedClientId;
  }

  // ================================================================
  // DATE PICKER - FROM
  // ================================================================

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _fromDate = picked;

      if (_toDate.isBefore(_fromDate)) {
        _toDate = _fromDate;
      }

      _hasGenerated = false;
    });
  }

  // ================================================================
  // DATE PICKER - TO
  // ================================================================

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      _toDate = picked;
      _hasGenerated = false;
    });
  }

  // ================================================================
  // GENERATE LEDGER
  // ================================================================

  Future<void> _generateLedger() async {
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a party',
          ),
        ),
      );

      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final company =
      ref.read(activeCompanyProvider);

      if (company == null) {
        throw Exception(
          'No active company selected',
        );
      }

      // ------------------------------------------------------------
      // GET ALL INVOICES
      // ------------------------------------------------------------

      final allInvoices =
      await ref.read(
        invoiceListProvider.future,
      );

      // ------------------------------------------------------------
      // GET CLIENT PAYMENTS
      // ------------------------------------------------------------

      final paymentRepository =
      ref.read(paymentRepositoryProvider);

      final allPayments =
      await paymentRepository
          .getClientPayments(
        company.id,
        _selectedClientId!,
      );

      // ------------------------------------------------------------
      // FILTER CLIENT INVOICES
      // ------------------------------------------------------------

      final clientInvoices =
      allInvoices.where((invoice) {
        return invoice.companyId ==
            company.id &&
            invoice.clientId ==
                _selectedClientId;
      }).toList();

      // ------------------------------------------------------------
      // OPENING BALANCE
      //
      // Everything BEFORE From Date.
      //
      // Invoice = Debit (+)
      // Payment = Credit (-)
      // ------------------------------------------------------------

      double openingBalance = 0;

      for (final invoice in clientInvoices) {
        if (_dateOnly(invoice.invoiceDate)
            .isBefore(
          _dateOnly(_fromDate),
        )) {
          openingBalance +=
              invoice.grandTotal;
        }
      }

      for (final payment in allPayments) {
        if (_dateOnly(payment.paymentDate)
            .isBefore(
          _dateOnly(_fromDate),
        )) {
          openingBalance -=
              payment.amount;
        }
      }

      // ------------------------------------------------------------
      // PERIOD TRANSACTIONS
      // ------------------------------------------------------------

      final periodEntries =
      <LedgerEntry>[];

      // Invoices
      for (final invoice in clientInvoices) {
        final date =
        _dateOnly(invoice.invoiceDate);

        if (!date.isBefore(
          _dateOnly(_fromDate),
        ) &&
            !date.isAfter(
              _dateOnly(_toDate),
            )) {
          periodEntries.add(
            LedgerEntry(
              date: invoice.invoiceDate,
              particulars: 'Invoice',
              reference:
              'INV-${invoice.invoiceNumber}',
              debit: invoice.grandTotal,
              credit: 0,
            ),
          );
        }
      }

      // Payments
      for (final payment in allPayments) {
        final date =
        _dateOnly(payment.paymentDate);

        if (!date.isBefore(
          _dateOnly(_fromDate),
        ) &&
            !date.isAfter(
              _dateOnly(_toDate),
            )) {
          periodEntries.add(
            LedgerEntry(
              date: payment.paymentDate,
              particulars:
              'Payment Received',
              reference: '-',
              debit: 0,
              credit: payment.amount,
            ),
          );
        }
      }

      // ------------------------------------------------------------
      // SORT
      // ------------------------------------------------------------

      periodEntries.sort(
            (a, b) =>
            a.date.compareTo(b.date),
      );

      // ------------------------------------------------------------
      // RUNNING BALANCE
      // ------------------------------------------------------------

      double runningBalance =
          openingBalance;

      double totalDebit = 0;
      double totalCredit = 0;

      for (final entry in periodEntries) {
        totalDebit += entry.debit;
        totalCredit += entry.credit;

        runningBalance =
            runningBalance +
                entry.debit -
                entry.credit;

        entry.balance =
            runningBalance;
      }

      // ------------------------------------------------------------
      // CLOSING BALANCE
      // ------------------------------------------------------------

      final closingBalance =
          openingBalance +
              totalDebit -
              totalCredit;

      if (!mounted) return;

      setState(() {
        _openingBalance =
            openingBalance;

        _totalDebit =
            totalDebit;

        _totalCredit =
            totalCredit;

        _closingBalance =
            closingBalance;

        _entries =
            periodEntries;

        _hasGenerated = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error generating ledger: $e',
          ),
        ),
      );
    }
  }

  // ================================================================
  // EXPORT PDF
  // ================================================================

  Future<void> _exportPdf(
      Client client,
      ) async {
    if (!_hasGenerated) return;

    try {
      final company =
      ref.read(activeCompanyProvider);

      if (company == null) {
        throw Exception(
          'No active company selected',
        );
      }

      // ------------------------------------------------------------
      // COMPANY ADDRESS
      // ------------------------------------------------------------

      final companyAddress =
      _joinAddress([
        company.billingAddress,
        company.billingCity,
        company.billingState,
        company.billingPincode,
      ]);

      // ------------------------------------------------------------
      // PARTY ADDRESS
      // ------------------------------------------------------------

      final clientAddress =
      _joinAddress([
        client.billingAddress,
        client.billingCity,
        client.billingState,
        client.billingPincode,
      ]);

      // ------------------------------------------------------------
      // GENERATE PDF
      // ------------------------------------------------------------

      final Uint8List pdfBytes =
      await LedgerPdfService
          .generateLedgerPdf(
        // Company
        companyName:
        company.businessName,

        companyAddress:
        companyAddress,

        companyPhone:
        company.mobileNumber,

        companyEmail:
        company.emailAddress,

        companyGst:
        company.gstNumber,

        // Party
        clientName:
        client.businessName,

        clientAddress:
        clientAddress,

        clientGst:
        client.gstNumber,

        // Ledger
        fromDate:
        _fromDate,

        toDate:
        _toDate,

        openingBalance:
        _openingBalance,

        totalDebit:
        _totalDebit,

        totalCredit:
        _totalCredit,

        closingBalance:
        _closingBalance,

        entries:
        _entries,
      );

      // ------------------------------------------------------------
      // FILE NAME
      // ------------------------------------------------------------

      final safeClientName =
      client.businessName.replaceAll(
        RegExp(
          r'[\\/:*?"<>|]',
        ),
        '_',
      );

      final fileName =
          'Ledger_${safeClientName}_${DateFormat('dd-MM-yyyy').format(_fromDate)}_to_${DateFormat('dd-MM-yyyy').format(_toDate)}.pdf';

      // ------------------------------------------------------------
      // SHARE / EXPORT
      // ------------------------------------------------------------

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to export PDF: $e',
          ),
        ),
      );
    }
  }


  // ================================================================
  // EXPORT EXCEL
  // ================================================================

  Future<void> _exportExcel(
      Client client,
      ) async {
    if (!_hasGenerated) return;

    try {
      final company =
      ref.read(activeCompanyProvider);

      if (company == null) {
        throw Exception(
          'No active company selected',
        );
      }

      // ------------------------------------------------------------
      // COMPANY ADDRESS
      // ------------------------------------------------------------

      final companyAddress =
      _joinAddress([
        company.billingAddress,
        company.billingCity,
        company.billingState,
        company.billingPincode,
      ]);

      // ------------------------------------------------------------
      // PARTY ADDRESS
      // ------------------------------------------------------------

      final clientAddress =
      _joinAddress([
        client.billingAddress,
        client.billingCity,
        client.billingState,
        client.billingPincode,
      ]);

      // ------------------------------------------------------------
      // GENERATE EXCEL
      // ------------------------------------------------------------

      final filePath =
      await LedgerExcelService
          .generateLedgerExcel(
        companyName:
        company.businessName,

        companyAddress:
        companyAddress,

        companyPhone:
        company.mobileNumber,

        companyEmail:
        company.emailAddress,

        companyGst:
        company.gstNumber,

        clientName:
        client.businessName,

        clientAddress:
        clientAddress,

        clientGst:
        client.gstNumber,

        fromDate:
        _fromDate,

        toDate:
        _toDate,

        openingBalance:
        _openingBalance,

        totalDebit:
        _totalDebit,

        totalCredit:
        _totalCredit,

        closingBalance:
        _closingBalance,

        entries:
        _entries,
      );

      // ------------------------------------------------------------
      // SHARE / EXPORT EXCEL
      // ------------------------------------------------------------

      await Share.shareXFiles(
        [
          XFile(filePath),
        ],
        text:
        'Ledger - ${client.businessName}',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to export Excel: $e',
          ),
        ),
      );
    }
  }


  // ================================================================
  // ADDRESS HELPER
  // ================================================================

  String _joinAddress(
      List<String?> values,
      ) {
    return values
        .where(
          (value) =>
      value != null &&
          value.trim().isNotEmpty,
    )
        .map(
          (value) => value!.trim(),
    )
        .join(', ');
  }

  // ================================================================
  // DATE ONLY
  // ================================================================

  DateTime _dateOnly(
      DateTime date,
      ) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // ================================================================
  // AMOUNT FORMAT
  // ================================================================

  String _formatAmount(
      double amount,
      ) {
    return _currency.format(
      amount.abs(),
    );
  }

  // ================================================================
  // BALANCE FORMAT
  // ================================================================

  String _balanceText(
      double balance,
      ) {
    if (balance == 0) {
      return '₹0';
    }

    return '${_formatAmount(balance)} '
        '${balance > 0 ? 'Dr' : 'Cr'}';
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final clientsAsync =
    ref.watch(clientListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ledger',
        ),
      ),
      body: clientsAsync.when(
        loading: () =>
        const Center(
          child:
          CircularProgressIndicator(),
        ),
        error: (
            error,
            stack,
            ) =>
            Center(
              child: Text(
                'Error: $error',
              ),
            ),
        data: (clients) =>
            _buildLedgerPage(
              clients,
            ),
      ),
    );
  }

  // ================================================================
  // LEDGER PAGE
  // ================================================================

  Widget _buildLedgerPage(
      List<Client> clients,
      ) {
    final selectedClient =
        clients
            .where(
              (client) =>
          client.id ==
              _selectedClientId,
        )
            .firstOrNull;

    return SingleChildScrollView(
      padding:
      const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------
          // PARTY
          // ----------------------------------------------------------

          const Text(
            'Party',
            style: TextStyle(
              fontWeight:
              FontWeight.w600,
              fontSize: 14,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          DropdownButtonFormField<String>(
            value: _selectedClientId,
            isExpanded: true,

            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
              fontSize: 14,
            ),

            dropdownColor:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF252525)
                : Colors.white,

            decoration: InputDecoration(
              hintText: 'Select Party',
              filled: true,
              fillColor:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF0F0F0),

              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),

              prefixIcon: Icon(
                Icons.person_outline,
                color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade300
                    : Colors.grey.shade700,
              ),

              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),

              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),

              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),

              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),

              hintStyle: TextStyle(
                color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),

            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade300
                  : Colors.grey.shade700,
            ),

            disabledHint: selectedClient != null
                ? Text(
              selectedClient.businessName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
                fontSize: 14,
              ),
            )
                : null,

            items: clients.map((client) {
              return DropdownMenuItem<String>(
                value: client.id,
                child: Text(
                  client.businessName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),

            onChanged: widget.preselectedClientId != null
                ? null
                : (value) {
              setState(() {
                _selectedClientId = value;
                _hasGenerated = false;
              });
            },
          ),

          const SizedBox(
            height: 20,
          ),

          // ----------------------------------------------------------
          // DATE RANGE
          // ----------------------------------------------------------

          Row(
            children: [
              Expanded(
                child:
                _DateBox(
                  label: 'From',
                  date:
                  _fromDate,
                  dateFormat:
                  _dateFormat,
                  onTap:
                  _pickFromDate,
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child:
                _DateBox(
                  label: 'To',
                  date:
                  _toDate,
                  dateFormat:
                  _dateFormat,
                  onTap:
                  _pickToDate,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          // ----------------------------------------------------------
          // VIEW LEDGER
          // ----------------------------------------------------------

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
              _loading ? null : _generateLedger,

              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                foregroundColor: Colors.white,

                disabledBackgroundColor:
                const Color(0xFF1877F2)
                    .withValues(alpha: 0.4),

                disabledForegroundColor: Colors.white,

                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              child: _loading
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'View Ledger',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ----------------------------------------------------------
          // GENERATED LEDGER
          // ----------------------------------------------------------

          if (_hasGenerated) ...[
            const SizedBox(
              height: 24,
            ),

            if (selectedClient !=
                null)
              Text(
                selectedClient
                    .businessName,
                style:
                const TextStyle(
                  fontSize: 20,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

            const SizedBox(
              height: 4,
            ),

            Text(
              '${_dateFormat.format(_fromDate)} - '
                  '${_dateFormat.format(_toDate)}',
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // --------------------------------------------------------
            // SUMMARY
            // --------------------------------------------------------

            _SummaryCard(
              openingBalance:
              _openingBalance,
              totalDebit:
              _totalDebit,
              totalCredit:
              _totalCredit,
              closingBalance:
              _closingBalance,
              balanceText:
              _balanceText,
              formatAmount:
              _formatAmount,
            ),

            const SizedBox(
              height: 20,
            ),

            // --------------------------------------------------------
            // TABLE
            // --------------------------------------------------------

            _buildLedgerTable(),

            const SizedBox(
              height: 16,
            ),

            // --------------------------------------------------------
            // NO TRANSACTIONS MESSAGE
            // --------------------------------------------------------

            if (_entries.isEmpty)
              const Padding(
                padding:
                EdgeInsets.only(
                  bottom: 16,
                ),
                child: Center(
                  child: Text(
                    'No transactions found '
                        'for this period.',
                  ),
                ),
              ),

            // --------------------------------------------------------
            // EXPORT PDF
            // --------------------------------------------------------

            if (selectedClient !=
                null) ...[
              SizedBox(
                width:
                double.infinity,
                height: 48,
                child:
                ElevatedButton.icon(
                  onPressed: () =>
                      _exportPdf(
                        selectedClient,
                      ),
                  icon:
                  const Icon(
                    Icons
                        .picture_as_pdf_outlined,
                    color: Colors.white,
                  ),
                  label:
                  const Text(
                    'Export PDF',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              SizedBox(
                width:
                double.infinity,
                height: 48,
                child:
                ElevatedButton.icon(
                  onPressed: () =>
                      _exportExcel(
                        selectedClient,
                      ),
                  icon:
                  const Icon(
                    Icons
                        .table_chart_outlined,
                    color: Colors.white,
                  ),
                  label:
                  const Text(
                    'Export Excel',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ================================================================
  // LEDGER TABLE
  // ================================================================

  Widget _buildLedgerTable() {
    double runningBalance =
        _openingBalance;

    final rows =
    <DataRow>[];

    // ------------------------------------------------------------
    // OPENING BALANCE
    // ------------------------------------------------------------

    rows.add(
      DataRow(
        cells: [
          DataCell(
            Text(
              DateFormat(
                'dd/MM/yyyy',
              ).format(
                _fromDate,
              ),
            ),
          ),

          const DataCell(
            Text(
              'Opening Balance',
              style:
              TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const DataCell(
            Text('-'),
          ),

          const DataCell(
            Text('-'),
          ),

          const DataCell(
            Text('-'),
          ),

          DataCell(
            Text(
              _balanceText(
                _openingBalance,
              ),
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    // ------------------------------------------------------------
    // TRANSACTIONS
    // ------------------------------------------------------------

    for (final entry
    in _entries) {
      runningBalance =
          runningBalance +
              entry.debit -
              entry.credit;

      rows.add(
        DataRow(
          cells: [
            DataCell(
              Text(
                DateFormat(
                  'dd/MM/yyyy',
                ).format(
                  entry.date,
                ),
              ),
            ),

            DataCell(
              Text(
                entry.particulars,
              ),
            ),

            DataCell(
              Text(
                entry.reference,
              ),
            ),

            DataCell(
              Text(
                entry.debit > 0
                    ? _formatAmount(
                  entry.debit,
                )
                    : '-',
              ),
            ),

            DataCell(
              Text(
                entry.credit > 0
                    ? _formatAmount(
                  entry.credit,
                )
                    : '-',
              ),
            ),

            DataCell(
              Text(
                _balanceText(
                  entry.balance,
                ),
                style:
                const TextStyle(
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------
    // CLOSING BALANCE
    // ------------------------------------------------------------

    rows.add(
      DataRow(
        cells: [
          DataCell(
            Text(
              DateFormat(
                'dd/MM/yyyy',
              ).format(
                _toDate,
              ),
            ),
          ),

          const DataCell(
            Text(
              'Closing Balance',
              style:
              TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),

          const DataCell(
            Text('-'),
          ),

          const DataCell(
            Text('-'),
          ),

          const DataCell(
            Text('-'),
          ),

          DataCell(
            Text(
              _balanceText(
                _closingBalance,
              ),
              style:
              const TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      clipBehavior:
      Clip.antiAlias,

      child:
      SingleChildScrollView(
        scrollDirection:
        Axis.horizontal,

        child: DataTable(
          columnSpacing:
          18,

          headingRowColor:
          WidgetStateProperty.all(
            Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
          ),

          columns: const [
            DataColumn(
              label: Text(
                'Date',
              ),
            ),

            DataColumn(
              label: Text(
                'Particulars',
              ),
            ),

            DataColumn(
              label: Text(
                'Ref',
              ),
            ),

            DataColumn(
              label: Text(
                'Debit',
              ),
            ),

            DataColumn(
              label: Text(
                'Credit',
              ),
            ),

            DataColumn(
              label: Text(
                'Balance',
              ),
            ),
          ],

          rows: rows,
        ),
      ),
    );
  }
}

// ======================================================================
// LEDGER ENTRY
// ======================================================================

class LedgerEntry {
  final DateTime date;
  final String particulars;
  final String reference;
  final double debit;
  final double credit;

  double balance;

  LedgerEntry({
    required this.date,
    required this.particulars,
    required this.reference,
    required this.debit,
    required this.credit,
    this.balance = 0,
  });
}

// ======================================================================
// DATE BOX
// ======================================================================

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateFormat dateFormat;
  final VoidCallback onTap;

  const _DateBox({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final textColor =
    isDark ? Colors.white : Colors.black87;

    final secondaryColor =
    isDark
        ? Colors.grey.shade300
        : Colors.grey.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),

      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,

          filled: true,

          fillColor: isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFF0F0F0),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),

          labelStyle: TextStyle(
            color: secondaryColor,
          ),

          floatingLabelStyle: TextStyle(
            color: secondaryColor,
          ),

          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: secondaryColor,
          ),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),

        child: Text(
          dateFormat.format(date),
          style: TextStyle(
            color: textColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// SUMMARY CARD
// ======================================================================

class _SummaryCard
    extends StatelessWidget {
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double closingBalance;

  final String Function(double)
  balanceText;

  final String Function(double)
  formatAmount;

  const _SummaryCard({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
    required this.balanceText,
    required this.formatAmount,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(
          16,
        ),

        child: Column(
          children: [
            _SummaryRow(
              label:
              'Opening Balance',
              value:
              balanceText(
                openingBalance,
              ),
            ),

            const Divider(),

            _SummaryRow(
              label:
              'Total Debit',
              value:
              formatAmount(
                totalDebit,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            _SummaryRow(
              label:
              'Total Credit',
              value:
              formatAmount(
                totalCredit,
              ),
            ),

            const Divider(),

            _SummaryRow(
              label:
              'Closing Balance',
              value:
              balanceText(
                closingBalance,
              ),
              bold: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// SUMMARY ROW
// ======================================================================

class _SummaryRow
    extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment
          .spaceBetween,

      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.w500,
          ),
        ),

        Text(
          value,
          style: TextStyle(
            fontWeight: bold
                ? FontWeight.bold
                : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}