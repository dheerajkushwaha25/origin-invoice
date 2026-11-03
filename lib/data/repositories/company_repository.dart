// lib/data/repositories/company_repository.dart
//
// ✅ FIREBASE VERSION — replaces the SQLite CompanyRepository.
// Public API is identical — company_provider.dart needs zero changes.

import 'package:ezinvoice/data/firebase/firebase_service.dart';
import 'package:ezinvoice/models/company.dart';

class CompanyRepository {
  final _fb = FirebaseService.instance;

  Future<int> insertOrUpdate(Company company) async {
    await _fb.insertOrUpdateCompany(company);
    return 1;
  }

  Future<List<Company>> getAllCompanies() async {
    return _fb.getAllCompanies();
  }

  Future<Company?> getFirstCompany() async {
    return _fb.getFirstCompany();
  }

  Future<int> deleteCompany(String id) async {
    await _fb.deleteCompany(id);
    return 1;
  }
}
