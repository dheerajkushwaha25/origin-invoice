// lib/models/invoice.dart

enum InvoiceStatus {
  pending, // 0
  paid,    // 1
  overdue  // 2
}

class Invoice {
  final String? id;
  final String companyId;
  final String clientId;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String notes;

  // PO fields
  final String? poNumber;
  final DateTime? poDate;

  // Logistics fields
  final String? transportMode;
  final String? vehicleNumber;

  // Challan fields
  final String? challanNumber;
  final DateTime? challanDate;

  // ✅ Terms & Conditions
  final String? termsAndConditions;

  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double cgstTotal;
  final double sgstTotal;
  final double grandTotal;
  final InvoiceStatus status;

  const Invoice({
    this.id,
    required this.companyId,
    required this.clientId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.subtotal,
    required this.cgstTotal,
    required this.sgstTotal,
    required this.grandTotal,
    this.notes = '',
    this.status = InvoiceStatus.pending,
    this.items = const [],
    this.poNumber,
    this.poDate,
    this.transportMode,
    this.vehicleNumber,
    this.challanNumber,
    this.challanDate,
    this.termsAndConditions,
  });
}
