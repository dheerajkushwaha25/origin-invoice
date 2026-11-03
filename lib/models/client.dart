// lib/models/client.dart

class Client {
  final String id;
  final String businessName;
  final String? phoneNumber;
  final String? email;
  final String? gstNumber;
  final String? billingAddress;
  final String? billingCity;
  final String? billingState;
  final String? billingPincode;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingState;
  final String? shippingPincode;

  // Added 'const' to the constructor
  const Client({
    required this.id,
    required this.businessName,
    this.phoneNumber,
    this.email,
    this.gstNumber,
    this.billingAddress,
    this.billingCity,
    this.billingState,
    this.billingPincode,
    this.shippingAddress,
    this.shippingCity,
    this.shippingState,
    this.shippingPincode,
  });
}