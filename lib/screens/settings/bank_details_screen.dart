import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/company.dart';
import 'package:ezinvoice/providers/company_provider.dart';

class BankDetailsScreen extends ConsumerStatefulWidget {
  final Company company;

  const BankDetailsScreen({super.key, required this.company});

  @override
  ConsumerState<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends ConsumerState<BankDetailsScreen> {
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscCodeController;
  late TextEditingController _accountHolderNameController;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  static const _blue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    final company = widget.company;
    _bankNameController = TextEditingController(text: company.bankName ?? '');
    _accountNumberController = TextEditingController(text: company.accountNumber ?? '');
    _ifscCodeController = TextEditingController(text: company.ifscCode ?? '');
    _accountHolderNameController = TextEditingController(text: company.accountHolderName ?? '');
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _accountHolderNameController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final updatedCompany = widget.company.copyWith(
        bankName: _bankNameController.text.isEmpty ? null : _bankNameController.text,
        accountNumber: _accountNumberController.text.isEmpty ? null : _accountNumberController.text,
        ifscCode: _ifscCodeController.text.isEmpty ? null : _ifscCodeController.text,
        accountHolderName: _accountHolderNameController.text.isEmpty ? null : _accountHolderNameController.text,
      );

      await ref.read(companyListProvider.notifier).updateCompany(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Bank details updated successfully!'),
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
            content: Text('Error saving bank details: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Details')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Info Banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: _blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'These details will appear on your invoices for client payments',
                      style: TextStyle(fontSize: 13, color: _blue.withValues(alpha: 0.85)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Bank Details Card ──────────────────────────────────────────
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
                      'BANK INFORMATION',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: _blue, letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _bankNameController,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g., State Bank of India',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _accountHolderNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                        hintText: 'Name as per bank records',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Please enter account holder name' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                        hintText: 'Your bank account number',
                        prefixIcon: Icon(Icons.tag_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) return 'Please enter account number';
                        if (value!.length < 9) return 'Account number must be at least 9 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _ifscCodeController,
                      decoration: const InputDecoration(
                        labelText: 'IFSC Code',
                        hintText: 'e.g., SBIN0001234',
                        prefixIcon: Icon(Icons.code_outlined),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) return 'Please enter IFSC code';
                        if (value!.length != 11) return 'IFSC code must be 11 characters';
                        return null;
                      },
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
                    : const Text('Save Bank Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
