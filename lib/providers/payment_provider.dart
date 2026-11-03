import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ezinvoice/data/repositories/payment_repository.dart';
import 'package:ezinvoice/models/payment.dart';
import 'package:ezinvoice/providers/company_provider.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

class PaymentListNotifier extends AsyncNotifier<List<Payment>> {
  @override
  Future<List<Payment>> build() async {
    final company = ref.watch(activeCompanyProvider);

    if (company == null) {
      return [];
    }

    final repository = ref.read(paymentRepositoryProvider);

    return repository.getCompanyPayments(company.id);
  }

  Future<void> addPayment({
    required String clientId,
    required double amount,
    required DateTime paymentDate,
  }) async {
    final company = ref.read(activeCompanyProvider);

    if (company == null) {
      throw Exception('No active company selected');
    }

    final payment = Payment(
      companyId: company.id,
      clientId: clientId,
      amount: amount,
      paymentDate: paymentDate,
    );

    final repository = ref.read(paymentRepositoryProvider);

    await repository.addPayment(payment);

    ref.invalidateSelf();
    await future;
  }

  Future<void> deletePayment(String paymentId) async {
    final repository = ref.read(paymentRepositoryProvider);

    await repository.deletePayment(paymentId);

    ref.invalidateSelf();
    await future;
  }

  Future<void> refreshPayments() async {
    ref.invalidateSelf();
    await future;
  }
}

final paymentListProvider =
AsyncNotifierProvider<PaymentListNotifier, List<Payment>>(
  PaymentListNotifier.new,
);