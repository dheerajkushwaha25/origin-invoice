// lib/services/invoice_upload_hook.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/drive_sync_provider.dart';

Future<void> autoUploadInvoicePdf({
  required WidgetRef ref,
  required String companyName,
  required DateTime date,
  required String invoiceNumber,
  required List<int> pdfBytes,
}) async {
  final drive = ref.read(driveSyncProvider);
  final folderId = await drive.ensureFolderPath([
    'EZInvoice',
    'Invoices',
    companyName,
    '${date.year}',
    '${date.month.toString().padLeft(2, '0')}',
  ]);
  final fileName = 'INV-${date.year}-${date.month.toString().padLeft(2, '0')}-$invoiceNumber.pdf';
  await drive.uploadInvoicePdf(parentFolderId: folderId, fileName: fileName, pdfBytes: pdfBytes);
}
