class Payment {
  final String? id;
  final String companyId;
  final String clientId;
  final double amount;
  final DateTime paymentDate;

  const Payment({
    this.id,
    required this.companyId,
    required this.clientId,
    required this.amount,
    required this.paymentDate,
  });

  Payment copyWith({
    String? id,
    String? companyId,
    String? clientId,
    double? amount,
    DateTime? paymentDate,
  }) {
    return Payment(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      clientId: clientId ?? this.clientId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
    );
  }
}