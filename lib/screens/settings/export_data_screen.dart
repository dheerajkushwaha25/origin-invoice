import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/providers/invoice_provider.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:ezinvoice/services/amazon_style_invoice_service.dart';

enum DatePreset { last1M, last3M, last6M, last1Y, custom }

extension DatePresetLabel on DatePreset {
  String get label {
    switch (this) {
      case DatePreset.last1M:
        return '1 Month';
      case DatePreset.last3M:
        return '3 Months';
      case DatePreset.last6M:
        return '6 Months';
      case DatePreset.last1Y:
        return '1 Year';
      case DatePreset.custom:
        return 'Custom';
    }
  }
}

class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  DatePreset _selectedPreset = DatePreset.last1M;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _selectedClientId;

  bool _exporting = false;
  String _exportStatus = '';

  // Keeps track of which export is running.
  // 'pdf' or 'excel'
  String? _exportType;

  // Controls whether all invoices are shown in the preview.
  bool _showAllInvoices = false;

  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
  );

  final _dateFmt = DateFormat('dd MMM yyyy');

  static const _blue = Color(0xFF1877F2);

  void _applyPreset(DatePreset preset) {
    final now = DateTime.now();

    setState(() {
      _selectedPreset = preset;
      _toDate = now;

      switch (preset) {
        case DatePreset.last1M:
          _fromDate = DateTime(
            now.year,
            now.month - 1,
            now.day,
          );
          break;

        case DatePreset.last3M:
          _fromDate = DateTime(
            now.year,
            now.month - 3,
            now.day,
          );
          break;

        case DatePreset.last6M:
          _fromDate = DateTime(
            now.year,
            now.month - 6,
            now.day,
          );
          break;

        case DatePreset.last1Y:
          _fromDate = DateTime(
            now.year - 1,
            now.month,
            now.day,
          );
          break;

        case DatePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _fromDate,
        end: _toDate,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _blue,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedPreset = DatePreset.custom;
        _fromDate = picked.start;
        _toDate = picked.end;
      });
    }
  }

  List<Invoice> _filterInvoices(List<Invoice> all) {
    final endOfDay = DateTime(
      _toDate.year,
      _toDate.month,
      _toDate.day,
      23,
      59,
      59,
    );

    return all.where((inv) {
      final inRange = !inv.invoiceDate.isBefore(_fromDate) &&
          !inv.invoiceDate.isAfter(endOfDay);

      final byClient =
          _selectedClientId == null ||
              inv.clientId == _selectedClientId;

      return inRange && byClient;
    }).toList()
      ..sort(
            (a, b) => a.invoiceDate.compareTo(b.invoiceDate),
      );
  }

  double _totalAmount(List<Invoice> invoices) {
    return invoices.fold(
      0.0,
          (sum, inv) => sum + inv.grandTotal,
    );
  }

  // ============================================================
  // PDF EXPORT
  // ============================================================

  Future<void> _exportPdf(List<Invoice> invoices) async {
    if (invoices.isEmpty) {
      _showSnack('No invoices to export');
      return;
    }

    setState(() {
      _exporting = true;
      _exportType = 'pdf';
      _exportStatus = 'Starting...';
    });

    try {
      final company = ref.read(activeCompanyProvider);
      final amazonService = AmazonStyleInvoiceService();
      final singleDoc = pw.Document();

      for (int i = 0; i < invoices.length; i++) {
        final inv = invoices[i];

        setState(() {
          _exportStatus =
          'Invoice ${i + 1} of ${invoices.length}...';
        });

        final client =
        await ref.read(
          clientDetailProvider(inv.clientId).future,
        );

        if (client == null) continue;

        await amazonService.addPageToDocument(
          singleDoc,
          inv,
          company,
          client,
        );
      }

      setState(() {
        _exportStatus = 'Saving PDF...';
      });

      final mergedBytes = await singleDoc.save();

      final dir = await getTemporaryDirectory();

      final fileName =
          'Invoices_${DateFormat('ddMMMyyyy').format(_fromDate)}_to_${DateFormat('ddMMMyyyy').format(_toDate)}.pdf';

      final outFile = File(
        '${dir.path}/$fileName',
      );

      await outFile.writeAsBytes(
        mergedBytes,
      );

      await Share.shareXFiles(
        [
          XFile(
            outFile.path,
            mimeType: 'application/pdf',
          ),
        ],
        subject:
        'Invoices ${_dateFmt.format(_fromDate)} – ${_dateFmt.format(_toDate)}',
      );
    } catch (e) {
      _showSnack('PDF export failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportType = null;
          _exportStatus = '';
        });
      }
    }
  }

  // ============================================================
  // EXCEL EXPORT
  // ============================================================

  Future<void> _exportExcel(
      List<Invoice> invoices,
      List<Client> clients,
      ) async {
    if (invoices.isEmpty) {
      _showSnack('No invoices to export');
      return;
    }

    setState(() {
      _exporting = true;
      _exportType = 'excel';
      _exportStatus = 'Building Excel...';
    });

    try {
      final clientMap = {
        for (final client in clients) client.id: client,
      };

      final workbook = excel.Excel.createExcel();

      final defaultSheetName =
      workbook.getDefaultSheet();

      if (defaultSheetName != null &&
          defaultSheetName != 'Invoices') {
        workbook.rename(
          defaultSheetName,
          'Invoices',
        );
      }

      final sheet = workbook['Invoices'];

      workbook.setDefaultSheet('Invoices');

      // ============================================================
      // HEADER
      // ============================================================

      sheet.appendRow([
        excel.TextCellValue('Invoice No'),
        excel.TextCellValue('Date'),
        excel.TextCellValue('Client Name'),
        excel.TextCellValue('Client GST'),
        excel.TextCellValue('Subtotal'),
        excel.TextCellValue('CGST'),
        excel.TextCellValue('SGST'),
        excel.TextCellValue('Grand Total'),
      ]);

      // ============================================================
      // INVOICE DATA
      // ============================================================

      for (final inv in invoices) {
        final client = clientMap[inv.clientId];

        sheet.appendRow([
          excel.TextCellValue(
            inv.invoiceNumber,
          ),

          excel.TextCellValue(
            DateFormat('dd/MM/yyyy').format(
              inv.invoiceDate,
            ),
          ),

          excel.TextCellValue(
            client?.businessName ?? '',
          ),

          excel.TextCellValue(
            client?.gstNumber ?? '',
          ),

          excel.TextCellValue(
            inv.subtotal.toStringAsFixed(2),
          ),

          excel.TextCellValue(
            inv.cgstTotal.toStringAsFixed(2),
          ),

          excel.TextCellValue(
            inv.sgstTotal.toStringAsFixed(2),
          ),

          excel.TextCellValue(
            inv.grandTotal.toStringAsFixed(2),
          ),
        ]);
      }

      // ============================================================
      // HEADER STYLE
      // ============================================================

      final headerStyle = excel.CellStyle(
        bold: true,
        verticalAlign: excel.VerticalAlign.Center,

        topBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
        ),

        bottomBorder: excel.Border(
          borderStyle: excel.BorderStyle.Thin,
        ),
      );

      for (int column = 0; column < 8; column++) {
        sheet
            .cell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: column,
            rowIndex: 0,
          ),
        )
            .cellStyle = headerStyle;
      }

      // ============================================================
      // COLUMN WIDTHS
      // ============================================================

      sheet.setColumnWidth(
        0,
        12,
      ); // Invoice No

      sheet.setColumnWidth(
        1,
        13,
      ); // Date

      sheet.setColumnWidth(
        2,
        24,
      ); // Client Name

      sheet.setColumnWidth(
        3,
        18,
      ); // Client GST

      sheet.setColumnWidth(
        4,
        14,
      ); // Subtotal

      sheet.setColumnWidth(
        5,
        12,
      ); // CGST

      sheet.setColumnWidth(
        6,
        12,
      ); // SGST

      sheet.setColumnWidth(
        7,
        16,
      ); // Grand Total

      // ============================================================
      // SAVE EXCEL
      // ============================================================

      setState(() {
        _exportStatus = 'Saving Excel...';
      });

      final bytes = workbook.save();

      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          'Excel file could not be generated.',
        );
      }

      final dir = await getTemporaryDirectory();

      final fileName =
          'Invoices_${DateFormat('ddMMMyyyy').format(_fromDate)}_to_${DateFormat('ddMMMyyyy').format(_toDate)}.xlsx';

      final file = File(
        '${dir.path}/$fileName',
      );

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      // ============================================================
      // SHARE EXCEL
      // ============================================================

      setState(() {
        _exportStatus = 'Saving Excel...';
      });

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Invoice Excel Export',
      );
    } catch (e) {
      _showSnack(
        'Excel export failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _exportType = null;
          _exportStatus = '';
        });
      }
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync =
    ref.watch(invoiceListProvider);

    final clientsAsync =
    ref.watch(clientListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),

      body: invoicesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),

        data: (allInvoices) => clientsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),

          error: (e, _) => Center(
            child: Text('Error: $e'),
          ),

          data: (allClients) {
            final filtered =
            _filterInvoices(allInvoices);

            final total =
            _totalAmount(filtered);

            return Stack(
              children: [
                ListView(
                  padding:
                  const EdgeInsets.all(16),

                  children: [
                    // ========================================================
                    // DATE PRESETS
                    // ========================================================

                    _sectionTitle(
                      'Filter by Date',
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,

                      children:
                      DatePreset.values.map(
                            (preset) {
                          final selected =
                              _selectedPreset ==
                                  preset;

                          return ChoiceChip(
                            label:
                            Text(preset.label),

                            selected: selected,

                            selectedColor:
                            _blue,

                            labelStyle:
                            TextStyle(
                              color: selected
                                  ? Colors.white
                                  : null,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight
                                  .normal,
                            ),

                            onSelected: (_) =>
                            preset ==
                                DatePreset
                                    .custom
                                ? _pickCustomRange()
                                : _applyPreset(
                              preset,
                            ),
                          );
                        },
                      ).toList(),
                    ),

                    const SizedBox(height: 10),

                    // ========================================================
                    // DATE RANGE
                    // ========================================================

                    InkWell(
                      onTap:
                      _pickCustomRange,

                      borderRadius:
                      BorderRadius.circular(
                        10,
                      ),

                      child: Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),

                        decoration:
                        BoxDecoration(
                          border: Border.all(
                            color: _selectedPreset ==
                                DatePreset.custom
                                ? _blue
                                : Colors
                                .grey
                                .shade300,

                            width:
                            _selectedPreset ==
                                DatePreset
                                    .custom
                                ? 1.5
                                : 1,
                          ),

                          borderRadius:
                          BorderRadius.circular(
                            10,
                          ),
                        ),

                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .calendar_month_outlined,
                              size: 18,
                              color: _selectedPreset ==
                                  DatePreset
                                      .custom
                                  ? _blue
                                  : Colors.grey,
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Text(
                              '${_dateFmt.format(_fromDate)}  →  ${_dateFmt.format(_toDate)}',

                              style:
                              const TextStyle(
                                fontSize: 14,
                              ),
                            ),

                            const Spacer(),

                            Icon(
                              Icons
                                  .edit_outlined,
                              size: 15,
                              color: Colors
                                  .grey
                                  .shade500,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ========================================================
                    // CLIENT FILTER
                    // ========================================================

                    _sectionTitle(
                      'Filter by Client',
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 14,
                      ),

                      decoration:
                      BoxDecoration(
                        border: Border.all(
                          color: Colors
                              .grey
                              .shade300,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          10,
                        ),
                      ),

                      child:
                      DropdownButtonHideUnderline(
                        child:
                        DropdownButton<
                            String?>(
                          value:
                          _selectedClientId,

                          isExpanded:
                          true,

                          hint:
                          const Text(
                            'All Clients',
                          ),

                          items: [
                            const DropdownMenuItem<
                                String?>(
                              value: null,
                              child: Text(
                                'All Clients',
                              ),
                            ),

                            ...allClients.map(
                                  (c) =>
                                  DropdownMenuItem<
                                      String?>(
                                    value: c.id,
                                    child: Text(
                                      c.businessName,
                                    ),
                                  ),
                            ),
                          ],

                          onChanged: (val) =>
                              setState(
                                    () =>
                                _selectedClientId =
                                    val,
                              ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ========================================================
                    // PREVIEW CARD
                    // ========================================================

                    Container(
                      padding:
                      const EdgeInsets.all(
                        16,
                      ),

                      decoration:
                      BoxDecoration(
                        color: _blue.withValues(
                          alpha: 0.05,
                        ),

                        borderRadius:
                        BorderRadius.circular(
                          14,
                        ),

                        border: Border.all(
                          color: _blue.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),

                      child: Column(
                        children: [
                          _previewRow(
                            'Invoices Found',
                            '${filtered.length}',
                            isBold: true,
                            color: _blue,
                          ),

                          const Divider(
                            height: 20,
                          ),

                          _previewRow(
                            'Total Amount',
                            _currency.format(
                              total,
                            ),
                          ),

                          if (_selectedClientId !=
                              null) ...[
                            const Divider(
                              height: 20,
                            ),

                            // ==================================================
                            // CLIENT NAME
                            // Fixed so long names wrap inside the card.
                            // ==================================================

                            Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Client',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors
                                        .grey
                                        .shade600,
                                  ),
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child: Text(
                                    allClients
                                        .cast<Client?>()
                                        .firstWhere(
                                          (c) =>
                                      c?.id ==
                                          _selectedClientId,
                                      orElse: () =>
                                      null,
                                    )
                                        ?.businessName ??
                                        'Unknown',

                                    textAlign:
                                    TextAlign.right,

                                    softWrap: true,

                                    style:
                                    const TextStyle(
                                      fontSize: 15,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ========================================================
                    // INVOICE LIST PREVIEW
                    // ========================================================

                    if (filtered.isNotEmpty) ...[
                      _sectionTitle(
                        'Preview (${filtered.length} invoices)',
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      // Show first 5 normally.
                      // If expanded, show all invoices.
                      ...(_showAllInvoices
                          ? filtered
                          : filtered.take(5))
                          .map(
                            (inv) {
                          final client =
                          allClients
                              .cast<Client?>()
                              .firstWhere(
                                (c) =>
                            c?.id ==
                                inv.clientId,
                            orElse: () =>
                            null,
                          );

                          return Padding(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              vertical: 4,
                            ),

                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                    children: [
                                      Text(
                                        '${inv.invoiceNumber}  ·  ${client?.businessName ?? "Unknown"}',

                                        softWrap:
                                        true,

                                        style:
                                        const TextStyle(
                                          fontSize:
                                          13,
                                          fontWeight:
                                          FontWeight
                                              .w500,
                                        ),
                                      ),

                                      Text(
                                        _dateFmt
                                            .format(
                                          inv.invoiceDate,
                                        ),

                                        style:
                                        TextStyle(
                                          fontSize:
                                          12,
                                          color: Colors
                                              .grey
                                              .shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                Text(
                                  _currency.format(
                                    inv.grandTotal,
                                  ),

                                  style:
                                  const TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                    FontWeight
                                        .w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // ======================================================
                      // SHOW MORE / SHOW LESS
                      // ======================================================

                      if (filtered.length > 5)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showAllInvoices =
                              !_showAllInvoices;
                            });
                          },

                          borderRadius:
                          BorderRadius.circular(
                            6,
                          ),

                          child: Padding(
                            padding:
                            const EdgeInsets
                                .only(
                              top: 6,
                              bottom: 2,
                            ),

                            child: Text(
                              _showAllInvoices
                                  ? 'Show less'
                                  : '+ ${filtered.length - 5} more invoices...',

                              style: TextStyle(
                                color: _blue,
                                fontSize: 12,
                                fontWeight:
                                FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 16,
                      ),
                    ],

                    // ========================================================
                    // EXPORT BUTTONS
                    // ========================================================

                    _sectionTitle(
                      'Export As',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ========================================================
                    // PDF BUTTON
                    // ========================================================

                    SizedBox(
                      width:
                      double.infinity,

                      height: 52,

                      child:
                      ElevatedButton(
                        onPressed:
                        (_exporting ||
                            filtered.isEmpty)
                            ? null
                            : () =>
                            _exportPdf(
                              filtered,
                            ),

                        child: Text(
                          _exportType == 'pdf'
                              ? _exportStatus
                              : 'Export PDF  (${filtered.length} invoices)',
                        ),

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          _blue,

                          foregroundColor:
                          Colors.white,

                          disabledBackgroundColor:
                          _blue.withValues(
                            alpha: 0.4,
                          ),

                          disabledForegroundColor:
                          Colors.white,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ========================================================
                    // EXCEL BUTTON
                    // ========================================================

                    SizedBox(
                      width:
                      double.infinity,

                      height: 52,

                      child:
                      ElevatedButton(
                        onPressed:
                        (_exporting ||
                            filtered.isEmpty)
                            ? null
                            : () =>
                            _exportExcel(
                              filtered,
                              allClients,
                            ),

                        child: Text(
                          _exportType == 'excel'
                              ? _exportStatus
                              : 'Export Excel  (${filtered.length} invoices)',
                        ),

                        style:
                        ElevatedButton
                            .styleFrom(
                          backgroundColor:
                          _blue,

                          foregroundColor:
                          Colors.white,

                          disabledBackgroundColor:
                          _blue.withValues(
                            alpha: 0.4,
                          ),

                          disabledForegroundColor:
                          Colors.white,

                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              12,
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (filtered.isEmpty)
                      Padding(
                        padding:
                        const EdgeInsets
                            .only(
                          top: 12,
                        ),

                        child: Center(
                          child: Text(
                            'No invoices found for selected filters',

                            style: TextStyle(
                              color: Colors
                                  .grey
                                  .shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(
                      height: 60,
                    ),
                  ],
                ),

                // ============================================================
                // PROGRESS OVERLAY
                // ============================================================

                if (_exporting)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,

                    child: Container(
                      color: Colors.black87,

                      padding:
                      const EdgeInsets
                          .symmetric(
                        vertical: 14,
                        horizontal: 20,
                      ),

                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,

                            child:
                            CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                              Colors.white,
                            ),
                          ),

                          const SizedBox(
                            width: 14,
                          ),

                          Expanded(
                            child: Text(
                              _exportStatus
                                  .isNotEmpty
                                  ? _exportStatus
                                  : 'Exporting...',

                              style:
                              const TextStyle(
                                color:
                                Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t.toUpperCase(),

      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _previewRow(
      String label,
      String value, {
        bool isBold = false,
        Color? color,
      }) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

      children: [
        Text(
          label,

          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),

        Text(
          value,

          style: TextStyle(
            fontSize: isBold ? 20 : 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}