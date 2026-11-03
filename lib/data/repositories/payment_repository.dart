import 'package:ezinvoice/data/firebase/firebase_service.dart';
import 'package:ezinvoice/models/payment.dart';

class PaymentRepository {
  final FirebaseService _firebaseService = FirebaseService.instance;

  Future<void> addPayment(Payment payment) async {
    await _firebaseService.insertPayment(payment);
  }

  Future<List<Payment>> getCompanyPayments(String companyId) async {
    return await _firebaseService.getCompanyPayments(companyId);
  }

  Future<List<Payment>> getClientPayments(
      String companyId,
      String clientId,
      ) async {
    return await _firebaseService.getClientPayments(
      companyId,
      clientId,
    );
  }

  Future<void> deletePayment(String id) async {
    await _firebaseService.deletePayment(id);
  }
}