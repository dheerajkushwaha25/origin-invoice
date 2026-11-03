class Company {
  final String id;
  final String businessName;
  final String? gstNumber;
  final String mobileNumber;
  final String emailAddress;
  final String billingAddress;
  final String billingCity;
  final String billingState;
  final String billingPincode;

  // Bank Details
  final String? bankName;
  final String? accountNumber;
  final String? ifscCode;
  final String? accountHolderName;

  // ✅ NEW: Logo and Signature paths
  final String? logoPath;
  final String? signaturePath;

  Company({
    required this.id,
    required this.businessName,
    this.gstNumber,
    required this.mobileNumber,
    required this.emailAddress,
    required this.billingAddress,
    required this.billingCity,
    required this.billingState,
    required this.billingPincode,
    this.bankName,
    this.accountNumber,
    this.ifscCode,
    this.accountHolderName,
    this.logoPath,  // ✅ ADDED
    this.signaturePath,  // ✅ ADDED
  });

  // ✅ copyWith method to create modified copies
  Company copyWith({
    String? id,
    String? businessName,
    String? gstNumber,
    String? mobileNumber,
    String? emailAddress,
    String? billingAddress,
    String? billingCity,
    String? billingState,
    String? billingPincode,
    String? bankName,
    String? accountNumber,
    String? ifscCode,
    String? accountHolderName,
    String? logoPath,
    String? signaturePath,
  }) {
    return Company(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      gstNumber: gstNumber ?? this.gstNumber,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      billingCity: billingCity ?? this.billingCity,
      billingState: billingState ?? this.billingState,
      billingPincode: billingPincode ?? this.billingPincode,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      logoPath: logoPath ?? this.logoPath,
      signaturePath: signaturePath ?? this.signaturePath,
    );
  }

  @override
  String toString() {
    return 'Company{id: $id, businessName: $businessName, gstNumber: $gstNumber}';
  }
}
