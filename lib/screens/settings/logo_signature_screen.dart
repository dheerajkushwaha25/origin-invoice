import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:ezinvoice/providers/company_provider.dart';

class LogoSignatureScreen extends ConsumerStatefulWidget {
  const LogoSignatureScreen({super.key});

  @override
  ConsumerState<LogoSignatureScreen> createState() => _LogoSignatureScreenState();
}

class _LogoSignatureScreenState extends ConsumerState<LogoSignatureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  static const _blue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadCompanyData());
  }

  Future<void> _reloadCompanyData() async {
    await ref.read(companyListProvider.notifier).refresh();
  }

  Future<void> _pickImage(ImageSource source, bool isLogo) async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) { setState(() => _isLoading = false); return; }

      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${isLogo ? 'logo' : 'signature'}_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedImage = File(path.join(directory.path, fileName));
      await File(image.path).copy(savedImage.path);

      final company = ref.read(activeCompanyProvider);
      final updatedCompany = isLogo
          ? company.copyWith(logoPath: savedImage.path)
          : company.copyWith(signaturePath: savedImage.path);

      await ref.read(companyListProvider.notifier).updateCompany(updatedCompany);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isLogo ? 'Logo' : 'Signature'} uploaded successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _showImageSourceSheet(bool isLogo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload ${isLogo ? 'Logo' : 'Signature'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt_outlined, color: _blue),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera, isLogo); },
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library_outlined, color: _blue),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing image'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery, isLogo); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeImage(bool isLogo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${isLogo ? 'Logo' : 'Signature'}?'),
        content: const Text('This will delete the uploaded image.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      setState(() => _isLoading = true);
      final company = ref.read(activeCompanyProvider);
      final oldPath = isLogo ? company.logoPath : company.signaturePath;
      if (oldPath != null && oldPath.isNotEmpty && File(oldPath).existsSync()) {
        await File(oldPath).delete();
      }
      final updatedCompany = isLogo
          ? company.copyWith(logoPath: '')
          : company.copyWith(signaturePath: '');
      await ref.read(companyListProvider.notifier).updateCompany(updatedCompany);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${isLogo ? 'Logo' : 'Signature'} removed'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(activeCompanyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logo & Signature'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _reloadCompanyData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _reloadCompanyData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageCard(
              title: 'Company Logo',
              subtitle: 'Upload your company logo for invoices',
              imagePath: company.logoPath,
              isLogo: true,
              emptyIcon: Icons.image_outlined,
              emptyLabel: 'No logo uploaded',
            ),
            const SizedBox(height: 16),
            _buildImageCard(
              title: 'Authorized Signature',
              subtitle: 'Upload signature for invoice authorization',
              imagePath: company.signaturePath,
              isLogo: false,
              emptyIcon: Icons.draw_outlined,
              emptyLabel: 'No signature uploaded',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard({
    required String title,
    required String subtitle,
    required String? imagePath,
    required bool isLogo,
    required IconData emptyIcon,
    required String emptyLabel,
  }) {
    final bool hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none),
      elevation: isDark ? 0 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: _blue, letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 14),
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasImage ? _blue.withValues(alpha: 0.3) : Colors.grey.shade200,
                  width: hasImage ? 1.5 : 1,
                ),
              ),
              child: hasImage
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(emptyIcon, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(emptyLabel,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => _showImageSourceSheet(isLogo),
                      icon: Icon(hasImage ? Icons.edit_outlined : Icons.upload_outlined, size: 18),
                      label: Text(hasImage ? 'Change' : 'Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 44,
                    width: 44,
                    child: OutlinedButton(
                      onPressed: () => _removeImage(isLogo),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
