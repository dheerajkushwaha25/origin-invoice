import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/providers/client_provider.dart';

const Map<String, String> _gstStateCodes = {
  '01': 'Jammu & Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab',
  '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana',
  '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh',
  '10': 'Bihar', '11': 'Sikkim', '12': 'Arunachal Pradesh',
  '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram',
  '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam',
  '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha',
  '22': 'Chhattisgarh', '23': 'Madhya Pradesh', '24': 'Gujarat',
  '25': 'Daman & Diu', '26': 'Dadra & Nagar Haveli', '27': 'Maharashtra',
  '28': 'Andhra Pradesh', '29': 'Karnataka', '30': 'Goa',
  '31': 'Lakshadweep', '32': 'Kerala', '33': 'Tamil Nadu',
  '34': 'Puducherry', '35': 'Andaman & Nicobar', '36': 'Telangana',
  '37': 'Andhra Pradesh (New)', '38': 'Ladakh',
  '97': 'Other Territory', '99': 'Centre Jurisdiction',
};

bool _isValidGstin(String gstin) {
  final regex = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$');
  return regex.hasMatch(gstin.toUpperCase());
}

Map<String, String>? _extractGstInfo(String gstin) {
  gstin = gstin.toUpperCase().trim();
  if (!_isValidGstin(gstin)) return null;
  final stateCode = gstin.substring(0, 2);
  final pan = gstin.substring(2, 12);
  final state = _gstStateCodes[stateCode] ?? 'Unknown State';
  return {'stateCode': stateCode, 'state': state, 'pan': pan};
}

class NewClientScreen extends ConsumerStatefulWidget {
  final Client? clientData;
  const NewClientScreen({super.key, this.clientData});

  @override
  ConsumerState<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends ConsumerState<NewClientScreen> {
  bool _isSameAsBilling = false;
  String? _gstError;

  late TextEditingController _businessNameController;
  late TextEditingController _gstNumberController;
  late TextEditingController _billingAddressController;
  late TextEditingController _billingCityController;
  late TextEditingController _billingStateController;
  late TextEditingController _billingPincodeController;
  late TextEditingController _shippingAddressController;
  late TextEditingController _shippingCityController;
  late TextEditingController _shippingStateController;
  late TextEditingController _shippingPincodeController;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final client = widget.clientData;
    _businessNameController = TextEditingController(text: client?.businessName);
    _gstNumberController = TextEditingController(text: client?.gstNumber);
    _billingAddressController = TextEditingController(text: client?.billingAddress);
    _billingCityController = TextEditingController(text: client?.billingCity);
    _billingStateController = TextEditingController(text: client?.billingState);
    _billingPincodeController = TextEditingController(text: client?.billingPincode);
    _shippingAddressController = TextEditingController(text: client?.shippingAddress);
    _shippingCityController = TextEditingController(text: client?.shippingCity);
    _shippingStateController = TextEditingController(text: client?.shippingState);
    _shippingPincodeController = TextEditingController(text: client?.shippingPincode);
    if (client != null && client.billingAddress == client.shippingAddress) {
      _isSameAsBilling = true;
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _gstNumberController.dispose();
    _billingAddressController.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPincodeController.dispose();
    _shippingAddressController.dispose();
    _shippingCityController.dispose();
    _shippingStateController.dispose();
    _shippingPincodeController.dispose();
    super.dispose();
  }

  void _onGstChanged(String value) {
    final gstin = value.toUpperCase().trim();
    if (gstin.isEmpty || gstin.length < 15) { setState(() => _gstError = null); return; }
    final info = _extractGstInfo(gstin);
    if (info == null) { setState(() => _gstError = 'Invalid GSTIN format'); return; }
    if (_billingStateController.text.isEmpty) {
      _billingStateController.text = info['state']!;
      if (_isSameAsBilling) _shippingStateController.text = info['state']!;
    }
    setState(() => _gstError = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('GSTIN valid — State: ${info['state']}, PAN: ${info['pan']}'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _copyBillingAddressToShipping() {
    if (_isSameAsBilling) {
      _shippingAddressController.text = _billingAddressController.text;
      _shippingCityController.text = _billingCityController.text;
      _shippingStateController.text = _billingStateController.text;
      _shippingPincodeController.text = _billingPincodeController.text;
    } else {
      _shippingAddressController.clear();
      _shippingCityController.clear();
      _shippingStateController.clear();
      _shippingPincodeController.clear();
    }
  }

  void _saveClient() async {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.clientData != null;
      final newClient = Client(
        id: isEditing ? widget.clientData!.id : DateTime.now().millisecondsSinceEpoch.toString(),
        businessName: _businessNameController.text,
        gstNumber: _gstNumberController.text.isNotEmpty ? _gstNumberController.text.toUpperCase() : null,
        billingAddress: _billingAddressController.text,
        billingCity: _billingCityController.text,
        billingState: _billingStateController.text,
        billingPincode: _billingPincodeController.text,
        shippingAddress: _isSameAsBilling ? _billingAddressController.text : _shippingAddressController.text,
        shippingCity: _isSameAsBilling ? _billingCityController.text : _shippingCityController.text,
        shippingState: _isSameAsBilling ? _billingStateController.text : _shippingStateController.text,
        shippingPincode: _isSameAsBilling ? _billingPincodeController.text : _shippingPincodeController.text,
      );
      await ref.read(clientListProvider.notifier).addClient(newClient);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${isEditing ? 'Updated' : 'Saved'} ${_businessNameController.text} successfully!')),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1877F2))),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _gap() => const SizedBox(height: 12);

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.clientData != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Client' : 'Add New Client')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [

              // ── Basic Info ───────────────────────────────────────────────
              _sectionCard(title: 'Basic Information', children: [
                TextFormField(
                  controller: _businessNameController,
                  decoration: const InputDecoration(labelText: 'Business/Company Name *'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Business Name is required.' : null,
                ),
                _gap(),
                TextFormField(
                  controller: _gstNumberController,
                  decoration: InputDecoration(
                    labelText: 'Client GST Number',
                    errorText: _gstError,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(15)],
                  onChanged: _onGstChanged,
                ),
              ]),

              // ── Billing Address ──────────────────────────────────────────
              _sectionCard(title: 'Billing Address', children: [
                TextFormField(controller: _billingAddressController, decoration: const InputDecoration(labelText: 'Address Line 1')),
                _gap(),
                TextFormField(controller: _billingCityController, decoration: const InputDecoration(labelText: 'Address Line 2')),
                _gap(),
                TextFormField(controller: _billingStateController, decoration: const InputDecoration(labelText: 'State')),
                _gap(),
                TextFormField(controller: _billingPincodeController, decoration: const InputDecoration(labelText: 'Pincode'), keyboardType: TextInputType.number),
              ]),

              // ── Shipping Address ─────────────────────────────────────────
              _sectionCard(title: 'Shipping Address', children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Same as Billing Address', style: TextStyle(fontSize: 14)),
                    Switch(
                      value: _isSameAsBilling,
                      onChanged: (val) => setState(() { _isSameAsBilling = val; _copyBillingAddressToShipping(); }),
                    ),
                  ],
                ),
                if (!_isSameAsBilling) ...[
                  _gap(),
                  TextFormField(controller: _shippingAddressController, decoration: const InputDecoration(labelText: 'Address Line 1')),
                  _gap(),
                  TextFormField(controller: _shippingCityController, decoration: const InputDecoration(labelText: 'Address Line 2')),
                  _gap(),
                  TextFormField(controller: _shippingStateController, decoration: const InputDecoration(labelText: 'State')),
                  _gap(),
                  TextFormField(controller: _shippingPincodeController, decoration: const InputDecoration(labelText: 'Pincode'), keyboardType: TextInputType.number),
                ],
              ]),

              // ── Save Button ──────────────────────────────────────────────
              ElevatedButton(
                onPressed: _saveClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1877F2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Save Client',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
