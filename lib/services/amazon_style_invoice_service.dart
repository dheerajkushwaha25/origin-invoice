// lib/services/amazon_style_invoice_service.dart
import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:intl/intl.dart';
import 'package:number_to_indian_words/number_to_indian_words.dart';

class AmazonStyleInvoiceService {

  Future<void> addPageToDocument(
      pw.Document doc, Invoice invoice, Company company, Client client, {
        double? discountPercent, double? discountAmount,
        double? cgstPercent, double? sgstPercent,
      }) async {
    final t = _calcTotals(invoice, discountPercent, discountAmount, cgstPercent, sgstPercent);
    doc.addPage(_buildPage(invoice, company, client, t, null, null));
  }

  Future<Uint8List> generatePdf(
      Invoice invoice, Company company, Client client, {
        String? transportMode, String? vehicleNumber,
        double? discountPercent, double? discountAmount,
        double? cgstPercent, double? sgstPercent,
      }) async {
    final pdf = pw.Document();
    final t   = _calcTotals(invoice, discountPercent, discountAmount, cgstPercent, sgstPercent);
    pdf.addPage(_buildPage(invoice, company, client, t, transportMode, vehicleNumber));
    return pdf.save();
  }

  pw.Page _buildPage(Invoice invoice, Company company, Client client, _Totals t,
      String? transportMode, String? vehicleNumber) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final numFmt     = NumberFormat('#,##,##0.00', 'en_IN');
    final tm         = (transportMode ?? invoice.transportMode ?? '').trim();
    final vn         = (vehicleNumber ?? invoice.vehicleNumber ?? '').trim();

    return pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        _buildHeader(company),
        pw.SizedBox(height: 16),
      ])
          : pw.SizedBox(),
      footer: (ctx) => ctx.pagesCount > 1
          ? pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9)),
      )
          : pw.SizedBox(),
      build: (ctx) => [
        _buildDetailsRow(invoice, client, dateFormat),
        pw.SizedBox(height: 12),
        _buildItemsTable(invoice.items, numFmt),
        pw.SizedBox(height: 10),
        _buildTotalsAndLogistics(
          subtotal: t.subtotal, base: t.base,
          discountPct: t.discountPct, discountAmount: t.discountAmt,
          effCgstPct: t.cgstPct, effSgstPct: t.sgstPct,
          cgst: t.cgst, sgst: t.sgst, grandTotal: t.grandTotal,
          numFmt: numFmt, transportMode: tm, vehicleNumber: vn,
          showAmountLabel: t.usingAmount,
        ),
        pw.SizedBox(height: 8),
        _buildAmountInWords(t.grandTotal, numFmt),
        if (invoice.notes.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildTextBox('Notes', invoice.notes),
        ],
        if ((invoice.termsAndConditions ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 8),
          _buildTextBox('Terms & Conditions', invoice.termsAndConditions!),
        ],
        pw.SizedBox(height: 16),
        _buildBottomSection(company),
      ],
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  pw.Widget _buildHeader(Company company) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('TAX INVOICE',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
          pw.SizedBox(height: 8),
          pw.Text(company.businessName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('GSTIN: ${company.gstNumber}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(company.billingAddress, style: const pw.TextStyle(fontSize: 9)),
          pw.Text('${company.billingCity}, ${company.billingState}, ${company.billingPincode}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text('Mobile: ${company.mobileNumber}', style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Email: ${company.emailAddress}', style: const pw.TextStyle(fontSize: 9)),
        ]),
        pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              pw.Text('ORIGINAL FOR RECIPIENT',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              if (company.logoPath != null &&
                  company.logoPath!.isNotEmpty &&
                  File(company.logoPath!).existsSync()) ...[
                pw.SizedBox(height: 28),
                pw.Container(
                  width: 120, height: 80, // ✅ bigger
                  child: pw.Image(pw.MemoryImage(File(company.logoPath!).readAsBytesSync()),
                      fit: pw.BoxFit.contain),
                ),
              ],
            ]),
      ],
    );
  }

  // ── DETAILS ROW ───────────────────────────────────────────────────────────
  pw.Widget _buildDetailsRow(Invoice invoice, Client client, DateFormat df) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _aligned('Invoice No',   invoice.invoiceNumber),
            pw.SizedBox(height: 4),
            _aligned('Invoice Date', df.format(invoice.invoiceDate)),
            if ((invoice.challanNumber ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _aligned('Challan No', invoice.challanNumber!),
            ],
            if (invoice.challanDate != null) ...[
              pw.SizedBox(height: 4),
              _aligned('Challan Date', df.format(invoice.challanDate!)),
            ],
            if ((invoice.poNumber ?? '').isNotEmpty) ...[
              pw.SizedBox(height: 4),
              _aligned('PO Number', invoice.poNumber!),
            ],
            if (invoice.poDate != null) ...[
              pw.SizedBox(height: 4),
              _aligned('PO Date', df.format(invoice.poDate!)),
            ],
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Billing address',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(client.businessName,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if (client.gstNumber != null && client.gstNumber!.isNotEmpty)
              pw.Text('GSTIN: ${client.gstNumber}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(client.billingAddress ?? 'N/A', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
                '${client.billingCity ?? ''}, ${client.billingState ?? ''}, ${client.billingPincode ?? ''}',
                style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Shipping address',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(client.businessName,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if (client.gstNumber != null && client.gstNumber!.isNotEmpty)
              pw.Text('GSTIN: ${client.gstNumber}', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(client.shippingAddress ?? client.billingAddress ?? 'N/A',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
                '${client.shippingCity ?? client.billingCity ?? ''}, '
                    '${client.shippingState ?? client.billingState ?? ''}, '
                    '${client.shippingPincode ?? client.billingPincode ?? ''}',
                style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      ],
    );
  }

  pw.Widget _aligned(String label, String value) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
          width: 75,
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
      pw.Text(':', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
    ]);
  }

  // ── ITEMS TABLE ───────────────────────────────────────────────────────────
  pw.Widget _buildItemsTable(List<Map<String, dynamic>> items, NumberFormat f) {
    final rows = <pw.TableRow>[
      // Header
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey300),
        children: [
          _th('#'),
          _th('Item', left: true),
          _th('HSN/SAC'),
          _th('Qty'),
          _th('Rate'),
          _th('Amount'),
        ],
      ),
    ];

    double totalAmt = 0;
    int    totalQty = 0;

    for (int i = 0; i < items.length; i++) {
      final it         = items[i];
      final double rate = (it['rate'] as num?)?.toDouble() ?? 0.0;
      final int qty     = _extractNumericQty(it['quantity']);
      totalAmt += rate * qty;
      totalQty += qty;

      rows.add(pw.TableRow(children: [
        _td((i + 1).toString()),
        _td(it['description'] ?? 'Item', left: true),
        _td(it['hsn_sac'] ?? 'N/A'),
        _td(it['quantity'].toString()),
        _tdRight(f.format(rate)),
        _tdRight(f.format(rate * qty)),
      ]));
    }

    // Total row
    rows.add(pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _td(''),
        _td('Total', bold: true, left: true),
        _td(''),
        _td('$totalQty', bold: true),
        _td(''),
        _tdRight(f.format(totalAmt), bold: true),
      ],
    ));

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(1),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.5),
      },
      children: rows,
    );
  }

  // ── TOTALS + LOGISTICS ────────────────────────────────────────────────────
  pw.Widget _buildTotalsAndLogistics({
    required double subtotal, required double base,
    required double discountPct, required double discountAmount,
    required double effCgstPct, required double effSgstPct,
    required double cgst, required double sgst, required double grandTotal,
    required NumberFormat numFmt,
    required String transportMode, required String vehicleNumber,
    bool showAmountLabel = false,
  }) {
    final f               = NumberFormat('#,##,##0.00', 'en_IN');
    final bool showDiscount  = discountAmount > 0.004;
    final bool showLogistics = transportMode.isNotEmpty || vehicleNumber.isNotEmpty;

    pw.Widget totalRow(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
    }

    final logistics = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (transportMode.isNotEmpty)
          pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('Transport Mode: $transportMode',
                  style: const pw.TextStyle(fontSize: 9))),
        if (vehicleNumber.isNotEmpty)
          pw.Text('Vehicle Number: $vehicleNumber',
              style: const pw.TextStyle(fontSize: 9)),
      ],
    );

    final totals = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        totalRow('Subtotal', f.format(subtotal)),
        if (showDiscount) ...[
          totalRow(
            showAmountLabel
                ? 'Discount (Rs)'
                : 'Discount (${discountPct.toStringAsFixed(2)}%)',
            '- ${f.format(discountAmount)}',
          ),
          totalRow('Total after Discount', f.format(base)),
        ],
        totalRow('CGST (${effCgstPct.toStringAsFixed(2)}%)', f.format(cgst)),
        totalRow('SGST (${effSgstPct.toStringAsFixed(2)}%)', f.format(sgst)),
        pw.Container(
          color: PdfColors.grey300,
          padding: const pw.EdgeInsets.all(6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rs ${f.format(grandTotal)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(flex: 11, child: showLogistics ? logistics : pw.SizedBox()),
        pw.Expanded(
            flex: 6,
            child: pw.Align(alignment: pw.Alignment.topRight, child: totals)),
      ],
    );
  }

  // ── AMOUNT IN WORDS ───────────────────────────────────────────────────────
  pw.Widget _buildAmountInWords(double total, NumberFormat f) {
    final words      = NumToWords.convertNumberToIndianWords(total.round());
    final capitalized = words.isNotEmpty
        ? '${words[0].toUpperCase()}${words.substring(1)}'
        : words;
    final formatter  = NumberFormat('#,##,##0.00', 'en_IN');

    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text('Total amount (in words): Rs $capitalized Only.',
                style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Amount Payable:',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text('Rs ${formatter.format(total)}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  // ── TEXT BOX (Notes / Terms) ──────────────────────────────────────────────
  pw.Widget _buildTextBox(String title, String content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('$title:',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(content, style: const pw.TextStyle(fontSize: 9)),
      ]),
    );
  }

  // ── BANK + SIGNATURE ──────────────────────────────────────────────────────
  pw.Widget _buildBottomSection(Company company) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Bank Details',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            _bank('Bank Name',      company.bankName ?? '___________________________'),
            _bank('A/c Holder',     company.accountHolderName ?? '___________________________'),
            _bank('Account Number', company.accountNumber ?? '___________________________'),
            _bank('IFSC Code',      company.ifscCode ?? '___________________________'),
          ]),
        ),
        pw.SizedBox(width: 40),
        pw.Expanded(
          flex: 1,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('For ${company.businessName}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 15),
            if (company.signaturePath != null &&
                company.signaturePath!.isNotEmpty &&
                File(company.signaturePath!).existsSync())
              pw.Container(
                width: 100, height: 40,
                child: pw.Image(
                    pw.MemoryImage(File(company.signaturePath!).readAsBytesSync()),
                    fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(height: 40),
            pw.SizedBox(height: 10),
            pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 8)),
          ]),
        ),
      ],
    );
  }

  pw.Widget _bank(String label, String value) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Container(
          width: 80,
          child: pw.Text(label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
      pw.Text(':', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(width: 8),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
    ]);
  }

  // ── Table cell helpers ────────────────────────────────────────────────────
  pw.Widget _th(String text, {bool left = false}) => pw.Container(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.center),
  );

  // Center-aligned data cell (for #, HSN, Qty)
  pw.Widget _td(String text, {bool bold = false, bool left = false}) => pw.Container(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: left ? pw.TextAlign.left : pw.TextAlign.center),
  );

  // ✅ Right-aligned cell for Rate and Amount with proper padding
  pw.Widget _tdRight(String text, {bool bold = false}) => pw.Container(
    padding: const pw.EdgeInsets.only(left: 4, right: 10, top: 6, bottom: 6),
    child: pw.Text(text,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        textAlign: pw.TextAlign.right),
  );

  // ── Qty extractor ─────────────────────────────────────────────────────────
  int _extractNumericQty(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    final n = v.toString().trim().replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(n) ?? 1;
  }

  // ── Totals calculator ─────────────────────────────────────────────────────
  _Totals _calcTotals(Invoice invoice, double? discountPercent, double? discountAmount,
      double? cgstPercent, double? sgstPercent) {
    double subtotal = 0.0;
    for (final item in invoice.items) {
      subtotal += ((item['rate'] as num?)?.toDouble() ?? 0.0) *
          _extractNumericQty(item['quantity']);
    }

    final double amtIn = (discountAmount ?? 0).isFinite ? (discountAmount ?? 0) : 0;
    final double pctIn = (discountPercent ?? 0).isFinite ? (discountPercent ?? 0) : 0;

    double discountAmt = 0, discountPct = 0, base = subtotal;
    bool usingAmount = false;

    if (amtIn > 0) {
      usingAmount = true;
      discountAmt = amtIn.clamp(0, subtotal);
      base        = subtotal - discountAmt;
      discountPct = subtotal == 0 ? 0 : (discountAmt / subtotal) * 100;
    } else if (pctIn > 0) {
      discountPct = pctIn.clamp(0, 100).toDouble();
      discountAmt = subtotal * (discountPct / 100);
      base        = subtotal - discountAmt;
    }

    final bool hasTaxOverride =
        (cgstPercent != null && cgstPercent > 0) || (sgstPercent != null && sgstPercent > 0);
    final double cgst    = hasTaxOverride ? base * ((cgstPercent ?? 0).clamp(0, 100) / 100) : invoice.cgstTotal;
    final double sgst    = hasTaxOverride ? base * ((sgstPercent ?? 0).clamp(0, 100) / 100) : invoice.sgstTotal;
    final double cgstPct = hasTaxOverride ? (cgstPercent ?? 0).clamp(0, 100).toDouble() : (base > 0 ? (cgst / base) * 100 : 0);
    final double sgstPct = hasTaxOverride ? (sgstPercent ?? 0).clamp(0, 100).toDouble() : (base > 0 ? (sgst / base) * 100 : 0);
    final double grandTotal = hasTaxOverride ? base + cgst + sgst : invoice.grandTotal;

    return _Totals(
      subtotal: subtotal, base: base, discountAmt: discountAmt, discountPct: discountPct,
      cgst: cgst, sgst: sgst, cgstPct: cgstPct, sgstPct: sgstPct,
      grandTotal: grandTotal, usingAmount: usingAmount,
    );
  }
}

class _Totals {
  final double subtotal, base, discountAmt, discountPct;
  final double cgst, sgst, cgstPct, sgstPct, grandTotal;
  final bool usingAmount;
  _Totals({
    required this.subtotal, required this.base,
    required this.discountAmt, required this.discountPct,
    required this.cgst, required this.sgst,
    required this.cgstPct, required this.sgstPct,
    required this.grandTotal, required this.usingAmount,
  });
}
