import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/providers/payment_provider.dart';

class ReceivePaymentScreen extends ConsumerStatefulWidget {
  final String? preselectedClientId;

  const ReceivePaymentScreen({
    super.key,
    this.preselectedClientId,
  });

  @override
  ConsumerState<ReceivePaymentScreen> createState() =>
      _ReceivePaymentScreenState();
}

class _ReceivePaymentScreenState
    extends ConsumerState<ReceivePaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedClientId;
  DateTime _paymentDate = DateTime.now();
  bool _isSaving = false;

  static const Color _blue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.preselectedClientId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a party'),
        ),
      );
      return;
    }

    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(paymentListProvider.notifier).addPayment(
        clientId: _selectedClientId!,
        amount: amount,
        paymentDate: _paymentDate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment saved successfully'),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save payments: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    Widget? suffixIcon,
  }) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,

      filled: true,

      // Light mode = light grey
      // Dark mode = dark grey
      fillColor: isDark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFF0F0F0),

      hintStyle: TextStyle(
        color: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
      ),

      suffixIconColor: isDark
          ? Colors.grey.shade300
          : Colors.grey.shade700,

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),

      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);

    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final primaryTextColor =
    isDark ? Colors.white : Colors.black87;

    final secondaryTextColor =
    isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Payment'),
      ),

      body: clientsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (error, stack) => Center(
          child: Text(
            'Failed to load parties: $error',
          ),
        ),

        data: (clients) {
          Client? selectedClient;

          if (_selectedClientId != null) {
            for (final client in clients) {
              if (client.id == _selectedClientId) {
                selectedClient = client;
                break;
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Form(
              key: _formKey,

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [
                  // ========================================================
                  // TITLE
                  // ========================================================

                  Text(
                    'Receive Payment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ========================================================
                  // PARTY
                  // ========================================================

                  Text(
                    'Party',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String>(
                    value: _selectedClientId,

                    isExpanded: true,

                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 14,
                    ),

                    dropdownColor: isDark
                        ? const Color(0xFF252525)
                        : Colors.white,

                    decoration: _fieldDecoration(
                      hintText: 'Select party',
                    ),

                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                    ),

                    // When the field is disabled because a client
                    // was preselected, use our own text color so it
                    // remains visible in dark mode.
                    disabledHint: selectedClient != null
                        ? Text(
                      selectedClient.businessName,
                      overflow:
                      TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 14,
                      ),
                    )
                        : Text(
                      'Select party',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),

                    items: clients.map((Client client) {
                      return DropdownMenuItem<String>(
                        value: client.id,

                        child: Text(
                          client.businessName,
                          overflow:
                          TextOverflow.ellipsis,

                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),

                    onChanged:
                    widget.preselectedClientId != null
                        ? null
                        : (value) {
                      setState(() {
                        _selectedClientId =
                            value;
                      });
                    },

                    validator: (value) {
                      if (value == null ||
                          value.isEmpty) {
                        return 'Please select a party';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ========================================================
                  // AMOUNT
                  // ========================================================

                  Text(
                    'Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    controller: _amountController,

                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 14,
                    ),

                    cursorColor: _blue,

                    keyboardType:
                    const TextInputType.numberWithOptions(
                      decimal: true,
                    ),

                    decoration: _fieldDecoration(
                      hintText: 'Enter amount',
                    ),

                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Please enter amount';
                      }

                      final amount =
                      double.tryParse(
                        value
                            .trim()
                            .replaceAll(',', ''),
                      );

                      if (amount == null ||
                          amount <= 0) {
                        return 'Enter a valid amount';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ========================================================
                  // DATE
                  // ========================================================

                  Text(
                    'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),

                  const SizedBox(height: 8),

                  InkWell(
                    onTap: _selectDate,

                    borderRadius:
                    BorderRadius.circular(10),

                    child: InputDecorator(
                      decoration: _fieldDecoration(
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 20,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),

                      child: Text(
                        DateFormat('dd-MM-yyyy')
                            .format(_paymentDate),

                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ========================================================
                  // SAVE PAYMENT
                  // ========================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,

                    child: ElevatedButton(
                      onPressed:
                      _isSaving
                          ? null
                          : _savePayment,

                      style:
                      ElevatedButton.styleFrom(
                        backgroundColor: _blue,

                        foregroundColor:
                        Colors.white,

                        disabledBackgroundColor:
                        _blue.withValues(
                          alpha: 0.4,
                        ),

                        disabledForegroundColor:
                        Colors.white,

                        elevation: 0,

                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                      ),

                      child: _isSaving
                          ? const SizedBox(
                        height: 22,
                        width: 22,

                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Save Payment',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}