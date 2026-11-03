import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/data/repositories/invoice_repository.dart';
import 'package:ezinvoice/providers/company_provider.dart';

final invoiceRepositoryProvider = Provider((ref) => InvoiceRepository());

class InvoiceListNotifier extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final repository = ref.watch(invoiceRepositoryProvider);
    final activeCompany = ref.watch(activeCompanyProvider);
    final currentCompanyId = activeCompany.id;
    if (currentCompanyId == '0') return [];
    return repository.getCompanyInvoices(currentCompanyId);
  }

  Future<void> addInvoice(Invoice invoice) async {
    state = const AsyncValue.loading();
    final repository = ref.read(invoiceRepositoryProvider);
    final currentCompanyId = ref.read(activeCompanyProvider).id;
    final invoiceWithCompanyId = Invoice(
      id: invoice.id,
      companyId: currentCompanyId,
      clientId: invoice.clientId,
      invoiceNumber: invoice.invoiceNumber,
      invoiceDate: invoice.invoiceDate,
      dueDate: invoice.dueDate,
      subtotal: invoice.subtotal,
      cgstTotal: invoice.cgstTotal,
      sgstTotal: invoice.sgstTotal,
      grandTotal: invoice.grandTotal,
      notes: invoice.notes,
      status: invoice.status,
      items: invoice.items,
      poNumber: invoice.poNumber,
      poDate: invoice.poDate,
      transportMode: invoice.transportMode,
      vehicleNumber: invoice.vehicleNumber,
      // ✅ FIXED — challan fields were missing, causing save to fail
      challanNumber: invoice.challanNumber,
      challanDate: invoice.challanDate,
      // ✅ Terms & Conditions
      termsAndConditions: invoice.termsAndConditions,
    );
    await repository.insertOrUpdate(invoiceWithCompanyId);
    ref.invalidateSelf();
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(
      currentList.where((i) => i.invoiceNumber != invoiceId && i.id != invoiceId).toList(),
    );
    final repository = ref.read(invoiceRepositoryProvider);
    await repository.deleteInvoice(invoiceId);
  }
}

final invoiceListProvider =
AsyncNotifierProvider<InvoiceListNotifier, List<Invoice>>(() {
  return InvoiceListNotifier();
});

// Sequential invoice numbering
final nextInvoiceNumberProvider =
FutureProvider.family<Map<String, String>, String>((ref, companyName) async {
  final invoices = ref.watch(invoiceListProvider).valueOrNull ?? [];
  int maxSerial = 0;
  for (var invoice in invoices) {
    final numeric = invoice.invoiceNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final serial = int.tryParse(numeric);
    if (serial != null && serial > maxSerial) maxSerial = serial;
  }
  final nextSerial = (maxSerial + 1).toString().padLeft(2, '0');
  return {'sequential': nextSerial, 'lastSerial': maxSerial.toString().padLeft(2, '0')};
});

// Default CGST / SGST
class DefaultGstNotifier extends AsyncNotifier<double> {
  final String _key;
  DefaultGstNotifier(this._key);

  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key) ?? 0.0;
  }

  Future<void> setValue(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, value);
    state = AsyncValue.data(value);
  }
}

final defaultCgstProvider =
AsyncNotifierProvider<DefaultGstNotifier, double>(() => DefaultGstNotifier('default_cgst'));

final defaultSgstProvider =
AsyncNotifierProvider<DefaultGstNotifier, double>(() => DefaultGstNotifier('default_sgst'));

// Sort key
final invoiceSortKeyProvider = StateProvider<String>((ref) => 'date_desc');
