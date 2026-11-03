// lib/data/repositories/invoice_repository.dart
//
// ✅ FIREBASE VERSION — replaces the SQLite InvoiceRepository.
// The public API (insertOrUpdate, getCompanyInvoices, deleteInvoice) is
// identical so invoice_provider.dart needs zero changes.

import 'package:ezinvoice/data/firebase/firebase_service.dart';
import 'package:ezinvoice/models/invoice.dart';

class InvoiceRepository {
  final _fb = FirebaseService.instance;

  Future<int> insertOrUpdate(Invoice invoice) async {
    await _fb.insertOrUpdateInvoice(invoice);
    return 1; // match SQLite return type expected by providers
  }

  Future<List<Invoice>> getCompanyInvoices(String companyId) async {
    return _fb.getCompanyInvoices(companyId);
  }

  Future<int> deleteInvoice(String id) async {
    await _fb.deleteInvoice(id);
    return 1;
  }
}
