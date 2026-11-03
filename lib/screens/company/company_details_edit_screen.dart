import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/providers/company_provider.dart';

class CompanyDetailsEditScreen extends ConsumerStatefulWidget {
  final Company company;

  const CompanyDetailsEditScreen({super.key, required this.company});

  @override
  ConsumerState<CompanyDetailsEditScreen> createState() => _CompanyDetailsEditScreenState();
}

class _CompanyDetailsEditScreenState extends ConsumerState<CompanyDetailsEditScreen> {
  late TextEditingController _nameController;
  late TextEditingController _gstController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _emailAddressController;
  late TextEditingController _billingAddressController;
  late TextEditingController _billingCityController;
  late TextEditingController _billingStateController;
  late TextEditingController _billingPincodeController;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  static const _blue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    final company = widget.company;
    _nameController = TextEditingController(text: company.businessName);
    _gstController = TextEditingController(text: company.gstNumber);
    _mobileNumberController = TextEditingController(text: company.mobileNumber);
    _emailAddressController = TextEditingController(text: company.emailAddress);
    _billingAddressController = TextEditingController(text: company.billingAddress);
    _billingCityController = TextEditingController(text: company.billingCity);
    _billingStateController = TextEditingController(text: company.billingState);
    _billingPincodeController = TextEditingController(text: company.billingPincode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gstController.dispose();
    _mobileNumberController.dispose();
    _emailAddressController.dispose();
    _billingAddressController.dispose();
    _billingCityController.dispose();
    _billingStateController.dispose();
    _billingPincodeController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updatedCompany = Company(
        id: widget.company.id,
        businessName: _nameController.text,
        gstNumber: _gstController.text,
        mobileNumber: _mobileNumberController.text,
        emailAddress: _emailAddressController.text,
        billingAddress: _billingAddressController.text,
        billingCity: _billingCityController.text,
        billingState: _billingStateController.text,
        billingPincode: _billingPincodeController.text,
      );

      await ref.read(companyListProvider.notifier).updateCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Company details updated!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteCompany(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Company?'),
        content: const Text('Are you sure you want to delete this company? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref.read(companyListProvider.notifier).deleteCompany(widget.company.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company deleted successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting company: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Company Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Business Info Card ─────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: Theme.of(context).brightness == Brightness.dark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none),
              elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BUSINESS INFO',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: _blue, letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Company Name',
                        hintText: 'Your business name',
                      ),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobileNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        hintText: 'e.g. 9876543210',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v!.isEmpty ? 'Mobile number is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailAddressController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'business@email.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gstController,
                      decoration: const InputDecoration(
                        labelText: 'GST Number',
                        hintText: 'e.g. 22AAAAA0000A1Z5',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Billing Address Card ───────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: Theme.of(context).brightness == Brightness.dark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none),
              elevation: Theme.of(context).brightness == Brightness.dark ? 0 : 1,
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BILLING ADDRESS',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: _blue, letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _billingAddressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _billingCityController,
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _billingStateController,
                            decoration: const InputDecoration(labelText: 'State'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _billingPincodeController,
                      decoration: const InputDecoration(labelText: 'Pincode'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Save Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _blue.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 16),

            // ── Delete Button ──────────────────────────────────────────────
            TextButton.icon(
              onPressed: () => _deleteCompany(context),
              icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
              label: const Text('Delete This Company',
                  style: TextStyle(color: Colors.red, fontSize: 14)),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
