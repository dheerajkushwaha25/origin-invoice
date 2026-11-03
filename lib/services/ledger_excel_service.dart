import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ezinvoice/screens/ledger/ledger_screen.dart';

class LedgerExcelService {
  static Future<String> generateLedgerExcel({
    required String companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyGst,
    required String clientName,
    String? clientAddress,
    String? clientGst,
    required DateTime fromDate,
    required DateTime toDate,
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
    required List<LedgerEntry> entries,
  }) async {
    final excel = Excel.createExcel();

    // ------------------------------------------------------------
    // SHEET
    // ------------------------------------------------------------

    final sheet = excel['Ledger'];

    excel.setDefaultSheet('Ledger');

    // ------------------------------------------------------------
    // FORMATTERS
    // ------------------------------------------------------------

    final dateFormat = DateFormat(
      'dd/MM/yyyy',
    );

    final currencyFormatter =
    NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );

    String clean(String? value) {
      return value?.trim() ?? '';
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

      return '${amount(value)} '
          '${value > 0 ? 'Dr' : 'Cr'}';
    }

    // ------------------------------------------------------------
    // ROW TRACKER
    // ------------------------------------------------------------

    int currentRow = 0;

    void addRow(List<CellValue> values) {
      sheet.appendRow(values);
      currentRow++;
    }

    // ============================================================
    // COMPANY DETAILS
    // ============================================================

    final companyNameRow = currentRow;

    addRow([
      TextCellValue(companyName),
    ]);

    if (clean(companyAddress).isNotEmpty) {
      addRow([
        TextCellValue(
          companyAddress!.trim(),
        ),
      ]);
    }

    final contact = <String>[];

    if (clean(companyPhone).isNotEmpty) {
      contact.add(
        'Phone: ${companyPhone!.trim()}',
      );
    }

    if (clean(companyEmail).isNotEmpty) {
      contact.add(
        'Email: ${companyEmail!.trim()}',
      );
    }

    if (contact.isNotEmpty) {
      addRow([
        TextCellValue(
          contact.join(' | '),
        ),
      ]);
    }

    if (clean(companyGst).isNotEmpty) {
      addRow([
        TextCellValue(
          'GSTIN: ${companyGst!.trim()}',
        ),
      ]);
    }

    // Empty row
    addRow([
      TextCellValue(''),
    ]);

    // ============================================================
    // PARTY DETAILS
    // ============================================================

    final partyNameRow = currentRow;

    addRow([
      TextCellValue('Party Name'),
      TextCellValue(clientName),
    ]);

    if (clean(clientAddress).isNotEmpty) {
      addRow([
        TextCellValue('Address'),
        TextCellValue(
          clientAddress!.trim(),
        ),
      ]);
    }

    if (clean(clientGst).isNotEmpty) {
      addRow([
        TextCellValue('GSTIN'),
        TextCellValue(
          clientGst!.trim(),
        ),
      ]);
    }

    // ------------------------------------------------------------
    // PERIOD
    // ------------------------------------------------------------

    addRow([
      TextCellValue('Period'),
      TextCellValue(
        '${dateFormat.format(fromDate)} '
            'to '
            '${dateFormat.format(toDate)}',
      ),
    ]);

    // Empty row
    addRow([
      TextCellValue(''),
    ]);

    // ============================================================
    // LEDGER HEADER
    //
    // THIS is the row that gets:
    // - Bold
    // - Line above
    // - Line below
    // ============================================================

    final headerRow = currentRow;

    addRow([
      TextCellValue('Date'),
      TextCellValue('Particulars'),
      TextCellValue('Ref'),
      TextCellValue('Debit'),
      TextCellValue('Credit'),
      TextCellValue('Balance'),
    ]);

    // ============================================================
    // OPENING BALANCE
    // ============================================================

    addRow([
      TextCellValue(
        dateFormat.format(fromDate),
      ),
      TextCellValue(
        'Opening Balance',
      ),
      TextCellValue('-'),
      TextCellValue('-'),
      TextCellValue('-'),
      TextCellValue(
        balanceText(openingBalance),
      ),
    ]);

    // ============================================================
    // TRANSACTIONS
    // ============================================================

    for (final entry in entries) {
      addRow([
        TextCellValue(
          dateFormat.format(entry.date),
        ),
        TextCellValue(
          entry.particulars,
        ),
        TextCellValue(
          entry.reference,
        ),
        TextCellValue(
          entry.debit > 0
              ? amount(entry.debit)
              : '-',
        ),
        TextCellValue(
          entry.credit > 0
              ? amount(entry.credit)
              : '-',
        ),
        TextCellValue(
          balanceText(entry.balance),
        ),
      ]);
    }

    // ============================================================
    // CLOSING BALANCE
    // ============================================================

    addRow([
      TextCellValue(
        dateFormat.format(toDate),
      ),
      TextCellValue(
        'Closing Balance',
      ),
      TextCellValue('-'),
      TextCellValue('-'),
      TextCellValue('-'),
      TextCellValue(
        balanceText(closingBalance),
      ),
    ]);

    // Empty row
    addRow([
      TextCellValue(''),
    ]);

    // ============================================================
    // SUMMARY
    // ============================================================

    addRow([
      TextCellValue(
        'Opening Balance',
      ),
      TextCellValue(
        balanceText(openingBalance),
      ),
    ]);

    addRow([
      TextCellValue(
        'Total Debit',
      ),
      TextCellValue(
        amount(totalDebit),
      ),
    ]);

    addRow([
      TextCellValue(
        'Total Credit',
      ),
      TextCellValue(
        amount(totalCredit),
      ),
    ]);

    addRow([
      TextCellValue(
        'Closing Balance',
      ),
      TextCellValue(
        balanceText(closingBalance),
      ),
    ]);

    // ============================================================
    // COMPANY NAME STYLE
    // ============================================================

    final companyNameStyle = CellStyle(
      bold: true,
      fontSize: 14,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 0,
        rowIndex: companyNameRow,
      ),
    )
        .cellStyle = companyNameStyle;

    // ============================================================
    // PARTY NAME STYLE
    // ============================================================

    final partyNameStyle = CellStyle(
      bold: true,
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
    );

    sheet
        .cell(
      CellIndex.indexByColumnRow(
        columnIndex: 1,
        rowIndex: partyNameRow,
      ),
    )
        .cellStyle = partyNameStyle;

    // ============================================================
    // LEDGER HEADER STYLE
    //
    // ONLY:
    // Date | Particulars | Ref | Debit | Credit | Balance
    //
    // Bold + line above + line below
    // ============================================================

    final headerStyle = CellStyle(
      bold: true,
      verticalAlign: VerticalAlign.Center,

      topBorder: Border(
        borderStyle: BorderStyle.Thin,
      ),

      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
      ),
    );

    for (int column = 0; column <= 5; column++) {
      sheet
          .cell(
        CellIndex.indexByColumnRow(
          columnIndex: column,
          rowIndex: headerRow,
        ),
      )
          .cellStyle = headerStyle;
    }

    // ============================================================
    // COLUMN WIDTHS
    // ============================================================

    sheet.setColumnWidth(
      0,
      13,
    ); // Date

    sheet.setColumnWidth(
      1,
      20,
    ); // Particulars

    sheet.setColumnWidth(
      2,
      10,
    ); // Ref

    sheet.setColumnWidth(
      3,
      12,
    ); // Debit

    sheet.setColumnWidth(
      4,
      12,
    ); // Credit

    sheet.setColumnWidth(
      5,
      16,
    ); // Balance

    // ============================================================
    // SAVE
    // ============================================================

    final bytes = excel.save();

    if (bytes == null || bytes.isEmpty) {
      throw Exception(
        'Excel file could not be generated.',
      );
    }

    final directory =
    await getApplicationDocumentsDirectory();

    await directory.create(
      recursive: true,
    );

    final safeClientName =
    clientName.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );

    final fileName =
        'Ledger_${safeClientName}_'
        '${DateFormat('dd-MM-yyyy').format(fromDate)}'
        '_to_'
        '${DateFormat('dd-MM-yyyy').format(toDate)}'
        '.xlsx';

    final file = File(
      '${directory.path}/$fileName',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    if (!await file.exists() ||
        await file.length() == 0) {
      throw Exception(
        'Excel file was created but contains no data.',
      );
    }

    return file.path;
  }
}