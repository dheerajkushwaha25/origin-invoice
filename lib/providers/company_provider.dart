import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/data/repositories/company_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kNoActiveCompanyId = '';

const String _hasCompanyKey = 'has_company';
const String _lastActiveCompanyKey = 'last_active_company_id';

Company get kPlaceholderCompany => Company(
  id: kNoActiveCompanyId,
  businessName: 'Setup Required',
  gstNumber: '',
  emailAddress: '',
  mobileNumber: '',
  billingAddress: '',
  billingCity: '',
  billingState: '',
  billingPincode: '',
  bankName: null,
  accountNumber: null,
  ifscCode: null,
  accountHolderName: null,
  logoPath: null,
  signaturePath: null,
);

final activeCompanyIdProvider = StateProvider<String>((ref) {
  return kNoActiveCompanyId;
});

class CompanyListNotifier extends StateNotifier<AsyncValue<List<Company>>> {
  final CompanyRepository _repository = CompanyRepository();

  CompanyListNotifier() : super(const AsyncValue.loading()) {
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _repository.getAllCompanies();

      // If companies are found, remember that this user
      // has successfully configured a company.
      if (companies.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_hasCompanyKey, true);
      }

      state = AsyncValue.data(companies);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addCompany(Company company) async {
    try {
      await _repository.insertOrUpdate(company);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompanyKey, true);
      await prefs.setString(_lastActiveCompanyKey, company.id);

      refetchCompanies();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateCompany(Company company) async {
    try {
      await _repository.insertOrUpdate(company);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hasCompanyKey, true);

      refetchCompanies();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteCompany(String id) async {
    try {
      await _repository.deleteCompany(id);

      final prefs = await SharedPreferences.getInstance();

      final savedCompanyId = prefs.getString(_lastActiveCompanyKey);

      if (savedCompanyId == id) {
        await prefs.remove(_lastActiveCompanyKey);
      }

      refetchCompanies();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> refresh() async {
    await _loadCompanies();
  }

  void refetchCompanies() {
    _loadCompanies();
  }
}

final companyListProvider =
StateNotifierProvider<CompanyListNotifier, AsyncValue<List<Company>>>((ref) {
  return CompanyListNotifier();
});

final activeCompanyProvider = Provider<Company>((ref) {
  final activeId = ref.watch(activeCompanyIdProvider);
  final companiesAsync = ref.watch(companyListProvider);

  return companiesAsync.when(
    data: (companies) {
      if (companies.isNotEmpty) {
        _loadLastActiveCompany(ref, companies);
      }

      // No companies currently available.
      if (companies.isEmpty) {
        return kPlaceholderCompany;
      }

      // No active company selected yet.
      if (activeId == kNoActiveCompanyId) {
        return companies.first;
      }

      // Return the currently selected company.
      try {
        return companies.firstWhere(
              (c) => c.id == activeId,
          orElse: () => companies.first,
        );
      } catch (_) {
        return companies.first;
      }
    },

    loading: () => kPlaceholderCompany,

    error: (_, __) => kPlaceholderCompany,
  );
});

void _loadLastActiveCompany(
    ProviderRef ref,
    List<Company> companies,
    ) async {
  if (companies.isEmpty) return;

  final currentActiveId = ref.read(activeCompanyIdProvider);

  if (currentActiveId != kNoActiveCompanyId) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();

  final savedCompanyId = prefs.getString(_lastActiveCompanyKey);

  // Restore the company that was being used previously.
  if (savedCompanyId != null &&
      companies.any((c) => c.id == savedCompanyId)) {
    ref.read(activeCompanyIdProvider.notifier).state = savedCompanyId;
    return;
  }

  // Fallback to the first company.
  ref.read(activeCompanyIdProvider.notifier).state = companies.first.id;
}

Future<void> switchCompany(
    WidgetRef ref,
    String companyId,
    ) async {
  ref.read(activeCompanyIdProvider.notifier).state = companyId;

  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    _lastActiveCompanyKey,
    companyId,
  );

  await prefs.setBool(
    _hasCompanyKey,
    true,
  );

  // Keep your existing refresh behavior so logo/signature
  // are reloaded from Firestore/local cache.
  await ref.read(companyListProvider.notifier).refresh();
}