// lib/providers/invoice_template_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum InvoiceTemplate {
  amazon,
}

extension InvoiceTemplateExtension on InvoiceTemplate {
  String get displayName {
    switch (this) {
      case InvoiceTemplate.amazon:
        return 'OriginX1'; // ✅ updated
    }
  }

  String get description {
    switch (this) {
      case InvoiceTemplate.amazon:
        return 'Default invoice template';
    }
  }
}

class InvoiceTemplateNotifier extends StateNotifier<InvoiceTemplate> {
  InvoiceTemplateNotifier() : super(InvoiceTemplate.amazon);

  void setTemplate(InvoiceTemplate template) {
    state = template;
  }
}

final invoiceTemplateProvider = StateNotifierProvider<InvoiceTemplateNotifier, InvoiceTemplate>((ref) {
  return InvoiceTemplateNotifier();
});
