import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ezinvoice/screens/ledger/ledger_screen.dart';

class LedgerPdfService {
  static Future<Uint8List> generateLedgerPdf({
    required String companyName,
    required String clientName,

    // ------------------------------------------------------------
    // COMPANY DETAILS
    // ------------------------------------------------------------

    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyGst,

    // ------------------------------------------------------------
    // PARTY DETAILS
    // ------------------------------------------------------------

    String? clientAddress,
    String? clientGst,

    // ------------------------------------------------------------
    // LEDGER DETAILS
    // ------------------------------------------------------------

    required DateTime fromDate,
    required DateTime toDate,
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
    required List<LedgerEntry> entries,
  }) async {
    final pdf = pw.Document();

    // ------------------------------------------------------------
    // FONT
    // ------------------------------------------------------------

    // Noto Sans supports the ₹ symbol correctly.
    final regularFont =
    await PdfGoogleFonts.notoSansRegular();

    final boldFont =
    await PdfGoogleFonts.notoSansBold();

    // ------------------------------------------------------------
    // FORMATTERS
    // ------------------------------------------------------------

    final dateFormat =
    DateFormat('dd/MM/yyyy');

    final currencyFormatter =
    NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    String clean(String? value) {
      if (value == null) {
        return '';
      }

      return value.trim();
    }

    String amount(double value) {
      return currencyFormatter.format(
        value.abs(),
      );
    }

    String balanceText(double value) {
      if (value == 0) {
        return '₹0';
      }

      return '${amount(value)} ${value > 0 ? 'Dr' : 'Cr'}';
    }

    // ------------------------------------------------------------
    // TABLE ROWS
    // ------------------------------------------------------------

    final tableRows = <List<String>>[];

    // Opening Balance
    tableRows.add([
      dateFormat.format(fromDate),
      'Opening Balance',
      '-',
      '-',
      '-',
      balanceText(openingBalance),
    ]);

    // Transactions
    for (final entry in entries) {
      tableRows.add([
        dateFormat.format(entry.date),
        entry.particulars,
        entry.reference,
        entry.debit > 0
            ? amount(entry.debit)
            : '-',
        entry.credit > 0
            ? amount(entry.credit)
            : '-',
        balanceText(entry.balance),
      ]);
    }

    // Closing Balance
    tableRows.add([
      dateFormat.format(toDate),
      'Closing Balance',
      '-',
      '-',
      '-',
      balanceText(closingBalance),
    ]);

    // ------------------------------------------------------------
    // PDF
    // ------------------------------------------------------------

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        margin: const pw.EdgeInsets.fromLTRB(
          28,
          28,
          28,
          28,
        ),

        theme: pw.ThemeData.withFont(
          base: regularFont,
          bold: boldFont,
        ),

        build: (context) {
          return [
            // ====================================================
            // COMPANY HEADER
            // ====================================================

            pw.Center(
              child: pw.Text(
                companyName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  font: boldFont,
                ),
              ),
            ),

            // ----------------------------------------------------
            // COMPANY ADDRESS
            // ----------------------------------------------------

            if (clean(companyAddress).isNotEmpty) ...[
              pw.SizedBox(height: 5),

              pw.Center(
                child: pw.Text(
                  companyAddress!.trim(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    font: regularFont,
                  ),
                ),
              ),
            ],

            // ----------------------------------------------------
            // PHONE + EMAIL
            // ----------------------------------------------------

            if (clean(companyPhone).isNotEmpty ||
                clean(companyEmail).isNotEmpty) ...[
              pw.SizedBox(height: 3),

              pw.Center(
                child: pw.Text(
                  [
                    if (clean(companyPhone).isNotEmpty)
                      companyPhone!.trim(),

                    if (clean(companyEmail).isNotEmpty)
                      companyEmail!.trim(),
                  ].join(' | '),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    font: regularFont,
                  ),
                ),
              ),
            ],

            // ----------------------------------------------------
            // COMPANY GSTIN
            // ----------------------------------------------------

            if (clean(companyGst).isNotEmpty) ...[
              pw.SizedBox(height: 3),

              pw.Center(
                child: pw.Text(
                  'GSTIN: ${companyGst!.trim()}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    font: regularFont,
                  ),
                ),
              ),
            ],

            pw.SizedBox(height: 10),

            pw.Divider(
              color: PdfColors.grey500,
              thickness: 0.8,
            ),

            pw.SizedBox(height: 14),

            // ====================================================
            // PARTY DETAILS
            // ====================================================

            _detailRow(
              'Party Name',
              clientName,
              regularFont,
              boldFont,
            ),

            if (clean(clientAddress).isNotEmpty)
              _detailRow(
                'Address',
                clientAddress!,
                regularFont,
                boldFont,
              ),

            if (clean(clientGst).isNotEmpty)
              _detailRow(
                'GSTIN',
                clientGst!,
                regularFont,
                boldFont,
              ),

            _detailRow(
              'Period',
              '${dateFormat.format(fromDate)} to ${dateFormat.format(toDate)}',
              regularFont,
              boldFont,
            ),

            pw.SizedBox(height: 18),

            // ====================================================
            // LEDGER TABLE
            // ====================================================

            pw.TableHelper.fromTextArray(
              headers: const [
                'Date',
                'Particulars',
                'Ref',
                'Debit',
                'Credit',
                'Balance',
              ],

              data: tableRows,

              border: pw.TableBorder.all(
                color: PdfColors.grey400,
                width: 0.5,
              ),

              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                font: boldFont,
              ),

              cellStyle: pw.TextStyle(
                fontSize: 8,
                font: regularFont,
              ),

              cellPadding:
              const pw.EdgeInsets.all(5),

              headerDecoration:
              const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),

              columnWidths: {
                0: const pw.FlexColumnWidth(1.3),
                1: const pw.FlexColumnWidth(2.2),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.4),
                5: const pw.FlexColumnWidth(1.6),
              },

              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
            ),

            pw.SizedBox(height: 18),

            // ====================================================
            // SUMMARY
            // SUMMARY IS AFTER THE TABLE
            // ====================================================

            pw.Container(
              width: double.infinity,

              padding:
              const pw.EdgeInsets.all(10),

              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: PdfColors.grey400,
                ),

                borderRadius:
                pw.BorderRadius.circular(5),
              ),

              child: pw.Column(
                children: [
                  _summaryRow(
                    'Opening Balance',
                    balanceText(openingBalance),
                    regularFont,
                    boldFont,
                  ),

                  pw.SizedBox(height: 6),

                  _summaryRow(
                    'Total Debit',
                    amount(totalDebit),
                    regularFont,
                    boldFont,
                  ),

                  pw.SizedBox(height: 6),

                  _summaryRow(
                    'Total Credit',
                    amount(totalCredit),
                    regularFont,
                    boldFont,
                  ),

                  pw.Divider(
                    color: PdfColors.grey500,
                  ),

                  _summaryRow(
                    'Closing Balance',
                    balanceText(closingBalance),
                    regularFont,
                    boldFont,
                    bold: true,
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // NO FOOTER
            // ----------------------------------------------------
          ];
        },
      ),
    );

    return pdf.save();
  }

  // ================================================================
  // PARTY DETAIL ROW
  // ================================================================

  static pw.Widget _detailRow(
      String label,
      String value,
      pw.Font regularFont,
      pw.Font boldFont,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        bottom: 6,
      ),

      child: pw.Row(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,

        children: [
          pw.SizedBox(
            width: 75,

            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight:
                pw.FontWeight.bold,
                font: boldFont,
              ),
            ),
          ),

          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 9.5,
                font: regularFont,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SUMMARY ROW
  // ================================================================

  static pw.Widget _summaryRow(
      String label,
      String value,
      pw.Font regularFont,
      pw.Font boldFont, {
        bool bold = false,
      }) {
    return pw.Row(
      mainAxisAlignment:
      pw.MainAxisAlignment.spaceBetween,

      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            font: bold
                ? boldFont
                : regularFont,
          ),
        ),

        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
            font: bold
                ? boldFont
                : regularFont,
          ),
        ),
      ],
    );
  }
}