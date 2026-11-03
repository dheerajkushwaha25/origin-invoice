import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ezinvoice/models/invoice.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/models/payment.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();

  FirebaseService._() {
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');
    return user.uid;
  }

  CollectionReference get _companies =>
      _db.collection('users').doc(_uid).collection('companies');
  CollectionReference get _clients =>
      _db.collection('users').doc(_uid).collection('clients');
  CollectionReference get _invoices =>
      _db.collection('users').doc(_uid).collection('invoices');
  CollectionReference get _payments =>
      _db.collection('users').doc(_uid).collection('payments');

  // ══════════════════════════════════════════════════════════════════════════
  // COMPANY
  // ══════════════════════════════════════════════════════════════════════════

  // ✅ Convert local image file to Base64 string for Firestore storage
  Future<String?> _imageToBase64(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    final file = File(filePath);
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // ✅ Write Base64 string back to a local file and return path
  Future<String?> _base64ToLocalFile(String? base64Str, String fileName) async {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      final dir   = await getApplicationDocumentsDirectory();
      final file  = File('${dir.path}/$fileName');
      final bytes = base64Decode(base64Str);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _companyToMap(Company c) async {
    // Convert local image files to Base64 for cross-device sync
    final logoBase64 = await _imageToBase64(c.logoPath);
    final sigBase64  = await _imageToBase64(c.signaturePath);

    return {
      'id': c.id,
      'businessName': c.businessName,
      'gstNumber': c.gstNumber,
      'mobileNumber': c.mobileNumber,
      'emailAddress': c.emailAddress,
      'billingAddress': c.billingAddress,
      'billingCity': c.billingCity,
      'billingState': c.billingState,
      'billingPincode': c.billingPincode,
      'bankName': c.bankName,
      'accountNumber': c.accountNumber,
      'ifscCode': c.ifscCode,
      'accountHolderName': c.accountHolderName,
      // ✅ If logo removed (empty path), explicitly set Base64 to null to clear it
      'logoBase64': logoBase64,
      'signatureBase64': sigBase64,
      'logoPath': c.logoPath,
      'signaturePath': c.signaturePath,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<Company> _companyFromMap(Map<String, dynamic> m) async {
    String? logoPath      = m['logoPath'];
    String? signaturePath = m['signaturePath'];

    // ✅ Only restore from Base64 if path is null (never set)
    // If path is explicitly '' (user deleted it), do NOT restore
    if (logoPath == null && m['logoBase64'] != null) {
      logoPath = await _base64ToLocalFile(
          m['logoBase64'] as String, 'logo_${m['id']}.png');
    } else if (logoPath != null && logoPath.isNotEmpty &&
        !File(logoPath).existsSync() && m['logoBase64'] != null) {
      // Path set but file missing (different device) — restore from Base64
      logoPath = await _base64ToLocalFile(
          m['logoBase64'] as String, 'logo_${m['id']}.png');
    }

    if (signaturePath == null && m['signatureBase64'] != null) {
      signaturePath = await _base64ToLocalFile(
          m['signatureBase64'] as String, 'signature_${m['id']}.png');
    } else if (signaturePath != null && signaturePath.isNotEmpty &&
        !File(signaturePath).existsSync() && m['signatureBase64'] != null) {
      signaturePath = await _base64ToLocalFile(
          m['signatureBase64'] as String, 'signature_${m['id']}.png');
    }

    return Company(
      id:                m['id'] ?? '',
      businessName:      m['businessName'] ?? '',
      gstNumber:         m['gstNumber'],
      mobileNumber:      m['mobileNumber'] ?? '',
      emailAddress:      m['emailAddress'] ?? '',
      billingAddress:    m['billingAddress'] ?? '',
      billingCity:       m['billingCity'] ?? '',
      billingState:      m['billingState'] ?? '',
      billingPincode:    m['billingPincode'] ?? '',
      bankName:          m['bankName'],
      accountNumber:     m['accountNumber'],
      ifscCode:          m['ifscCode'],
      accountHolderName: m['accountHolderName'],
      logoPath:          logoPath,
      signaturePath:     signaturePath,
    );
  }

  Future<void> insertOrUpdateCompany(Company company) async {
    final data = await _companyToMap(company);
    await _companies.doc(company.id).set(data, SetOptions(merge: true));
  }

  Future<List<Company>> getAllCompanies() async {
    final snap = await _companies.get();
    final futures = snap.docs.map((d) =>
        _companyFromMap(d.data() as Map<String, dynamic>));
    return Future.wait(futures);
  }

  Future<Company?> getFirstCompany() async {
    final snap = await _companies.limit(1).get();
    if (snap.docs.isEmpty) return null;
    return _companyFromMap(snap.docs.first.data() as Map<String, dynamic>);
  }

  Future<void> deleteCompany(String id) async {
    await _companies.doc(id).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLIENT
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _clientToMap(Client c) => {
    'id': c.id,
    'businessName': c.businessName,
    'phoneNumber': c.phoneNumber,
    'email': c.email,
    'gstNumber': c.gstNumber,
    'billingAddress': c.billingAddress,
    'billingCity': c.billingCity,
    'billingState': c.billingState,
    'billingPincode': c.billingPincode,
    'shippingAddress': c.shippingAddress,
    'shippingCity': c.shippingCity,
    'shippingState': c.shippingState,
    'shippingPincode': c.shippingPincode,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Client _clientFromMap(Map<String, dynamic> m) => Client(
    id: m['id'] ?? '',
    businessName: m['businessName'] ?? '',
    phoneNumber: m['phoneNumber'],
    email: m['email'],
    gstNumber: m['gstNumber'],
    billingAddress: m['billingAddress'],
    billingCity: m['billingCity'],
    billingState: m['billingState'],
    billingPincode: m['billingPincode'],
    shippingAddress: m['shippingAddress'],
    shippingCity: m['shippingCity'],
    shippingState: m['shippingState'],
    shippingPincode: m['shippingPincode'],
  );

  Future<void> insertOrUpdateClient(Client client) async {
    await _clients.doc(client.id).set(_clientToMap(client), SetOptions(merge: true));
  }

  Future<List<Client>> getAllClients() async {
    final snap = await _clients.orderBy('businessName').get();
    return snap.docs.map((d) => _clientFromMap(d.data() as Map<String, dynamic>)).toList();
  }

  Future<Client?> getClientById(String id) async {
    final doc = await _clients.doc(id).get();
    if (!doc.exists) return null;
    return _clientFromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> deleteClient(String id) async {
    await _clients.doc(id).delete();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INVOICE
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _invoiceToMap(Invoice inv) => {
    'id': inv.id,
    'companyId': inv.companyId,
    'clientId': inv.clientId,
    'invoiceNumber': inv.invoiceNumber,
    'invoiceDate': inv.invoiceDate.millisecondsSinceEpoch,
    'dueDate': inv.dueDate.millisecondsSinceEpoch,
    'subtotal': inv.subtotal,
    'cgstTotal': inv.cgstTotal,
    'sgstTotal': inv.sgstTotal,
    'grandTotal': inv.grandTotal,
    'notes': inv.notes,
    'status': inv.status.index,
    'items': json.encode(inv.items),
    'poNumber': inv.poNumber,
    'poDate': inv.poDate?.millisecondsSinceEpoch,
    'transportMode': inv.transportMode,
    'vehicleNumber': inv.vehicleNumber,
    // ✅ NEW: Challan fields
    'challanNumber': inv.challanNumber,
    'challanDate': inv.challanDate?.millisecondsSinceEpoch,
    // ✅ Terms & Conditions
    'termsAndConditions': inv.termsAndConditions,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Invoice _invoiceFromMap(Map<String, dynamic> m) {
    final itemsJson = json.decode(m['items'] ?? '[]') as List<dynamic>;
    final itemsList = itemsJson.map((e) => Map<String, dynamic>.from(e)).toList();

    return Invoice(
      id: m['id'],
      companyId: m['companyId'] ?? '',
      clientId: m['clientId'] ?? '',
      invoiceNumber: m['invoiceNumber'] ?? '',
      invoiceDate: DateTime.fromMillisecondsSinceEpoch(m['invoiceDate'] as int),
      dueDate: DateTime.fromMillisecondsSinceEpoch(
          (m['dueDate'] as int?) ?? m['invoiceDate'] as int),
      subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0.0,
      cgstTotal: (m['cgstTotal'] as num?)?.toDouble() ?? 0.0,
      sgstTotal: (m['sgstTotal'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (m['grandTotal'] as num?)?.toDouble() ?? 0.0,
      notes: m['notes'] ?? '',
      status: InvoiceStatus.values[m['status'] as int? ?? 0],
      items: itemsList,
      poNumber: m['poNumber'],
      poDate: m['poDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['poDate'] as int)
          : null,
      transportMode: m['transportMode'],
      vehicleNumber: m['vehicleNumber'],
      // ✅ NEW: Challan fields
      challanNumber: m['challanNumber'],
      challanDate: m['challanDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(m['challanDate'] as int)
          : null,
      // ✅ Terms & Conditions
      termsAndConditions: m['termsAndConditions'],
    );
  }

  Future<void> insertOrUpdateInvoice(Invoice invoice) async {
    final docKey = invoice.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _invoices.doc(docKey).set(_invoiceToMap(invoice), SetOptions(merge: true));
  }

  Future<List<Invoice>> getCompanyInvoices(String companyId) async {
    final snap = await _invoices
        .where('companyId', isEqualTo: companyId)
        .orderBy('invoiceDate', descending: true)
        .get();
    return snap.docs
        .map((d) => _invoiceFromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteInvoice(String id) async {
    // id here is invoice.id (timestamp string) passed from provider
    // Try direct doc delete first (old docs stored by invoice.id)
    try {
      final directSnap = await _invoices.doc(id).get();
      if (directSnap.exists) {
        await _invoices.doc(id).delete();
        return;
      }
    } catch (_) {}

    // Try by 'id' field (new docs stored by companyId_invoiceNumber key)
    final snap = await _invoices.where('id', isEqualTo: id).limit(1).get();
    if (snap.docs.isNotEmpty) {
      await snap.docs.first.reference.delete();
      return;
    }

    // Try by invoiceNumber field as last resort
    final snap2 = await _invoices.where('invoiceNumber', isEqualTo: id).limit(1).get();
    if (snap2.docs.isNotEmpty) {
      await snap2.docs.first.reference.delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PAYMENT
  // ══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> _paymentToMap(Payment payment) => {
    'id': payment.id,
    'companyId': payment.companyId,
    'clientId': payment.clientId,
    'amount': payment.amount,
    'paymentDate': payment.paymentDate.millisecondsSinceEpoch,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Payment _paymentFromMap(Map<String, dynamic> m) {
    return Payment(
      id: m['id'],
      companyId: m['companyId'] ?? '',
      clientId: m['clientId'] ?? '',
      amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.fromMillisecondsSinceEpoch(
        m['paymentDate'] as int,
      ),
    );
  }

  Future<void> insertPayment(Payment payment) async {
    final docKey =
        payment.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final paymentWithId = payment.copyWith(id: docKey);

    await _payments
        .doc(docKey)
        .set(_paymentToMap(paymentWithId), SetOptions(merge: true));
  }

  Future<List<Payment>> getCompanyPayments(String companyId) async {
    final snap = await _payments
        .where('companyId', isEqualTo: companyId)
        .orderBy('paymentDate', descending: true)
        .get();

    return snap.docs
        .map((d) => _paymentFromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<List<Payment>> getClientPayments(
      String companyId,
      String clientId,
      ) async {
    final snap = await _payments
        .where('companyId', isEqualTo: companyId)
        .where('clientId', isEqualTo: clientId)
        .orderBy('paymentDate', descending: true)
        .get();

    return snap.docs
        .map((d) => _paymentFromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePayment(String id) async {
    await _payments.doc(id).delete();
  }
}