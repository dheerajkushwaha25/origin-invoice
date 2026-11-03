// lib/screens/setup/first_time_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ezinvoice/screens/app_scaffold.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/providers/company_provider.dart';

class FirstTimeSetupScreen extends ConsumerStatefulWidget {
  const FirstTimeSetupScreen({super.key});

  @override
  ConsumerState<FirstTimeSetupScreen> createState() => _FirstTimeSetupScreenState();
}

class _FirstTimeSetupScreenState extends ConsumerState<FirstTimeSetupScreen> {
  bool? _hasGstNumber;

  final _companyNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailAddressController = TextEditingController();
  final _billingAddressController = TextEditingController();
  final _billingCityController = TextEditingController();
  final _billingStateController = TextEditingController();
  final _billingPincodeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _companyNameController.dispose();
    _gstNumberController.dispose();
    _mobileNumberController.dispose();
    _emailAddressController.dispose();
    _billingAddressController.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final newCompany = Company(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      businessName: _companyNameController.text.trim(),
      gstNumber: _hasGstNumber == true ? _gstNumberController.text.trim() : '',
      mobileNumber: _mobileNumberController.text.trim(),
      emailAddress: _emailAddressController.text.trim(),
      billingAddress: _billingAddressController.text.trim(),
      billingCity: _billingCityController.text.trim(),
      billingState: _billingStateController.text.trim(),
      billingPincode: _billingPincodeController.text.trim(),
      bankName: null,
      accountNumber: null,
      ifscCode: null,
      accountHolderName: null,
      logoPath: null,
      signaturePath: null,
    );

    await ref.read(companyListProvider.notifier).addCompany(newCompany);
    ref.read(activeCompanyIdProvider.notifier).state = newCompany.id;

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppScaffold()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldFillColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('Setup Your Company')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text('Company Name *',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _companyNameController,
                decoration: InputDecoration(hintText: 'Enter Company Name', filled: true, fillColor: fieldFillColor),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a company name.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileNumberController,
                decoration: InputDecoration(hintText: 'Mobile Number *', filled: true, fillColor: fieldFillColor),
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Mobile number is required.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailAddressController,
                decoration: InputDecoration(hintText: 'Email Address *', filled: true, fillColor: fieldFillColor),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required.' : null,
              ),
              const SizedBox(height: 20),
              const Text('Do you have a GST Number?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Yes, I have one'),
                      value: true,
                      groupValue: _hasGstNumber,
                      onChanged: (v) => setState(() => _hasGstNumber = v),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('No, I do not'),
                      value: false,
                      groupValue: _hasGstNumber,
                      onChanged: (v) => setState(() => _hasGstNumber = v),
                    ),
                  ),
                ],
              ),
              if (_hasGstNumber == true) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _gstNumberController,
                  decoration: InputDecoration(hintText: 'GST Number', filled: true, fillColor: fieldFillColor),
                  validator: (v) => (_hasGstNumber == true && (v == null || v.trim().isEmpty))
                      ? 'Please enter your GST number.' : null,
                ),
              ],
              const SizedBox(height: 20),
              ExpansionTile(
                leading: const Icon(Icons.location_on),
                title: const Text('Add Billing Address'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _billingAddressController,
                          decoration: InputDecoration(hintText: 'Address Line', filled: true, fillColor: fieldFillColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter address line.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _billingCityController,
                          decoration: InputDecoration(hintText: 'City', filled: true, fillColor: fieldFillColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter city.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _billingStateController,
                          decoration: InputDecoration(hintText: 'State', filled: true, fillColor: fieldFillColor),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter state.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _billingPincodeController,
                          decoration: InputDecoration(hintText: 'Pincode', filled: true, fillColor: fieldFillColor),
                          keyboardType: TextInputType.number,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter pincode.' : null,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _hasGstNumber == null ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save & Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'You can add bank details later in Settings',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
