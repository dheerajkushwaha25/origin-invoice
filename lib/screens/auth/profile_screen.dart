// lib/screens/auth/profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:ezinvoice/screens/auth/image_crop_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _blue = Color(0xFF1877F2);
  bool _uploadingPhoto = false;
  bool _savingName = false;
  String? _base64Photo;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _loadPhotoFromFirestore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotoFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['profilePhotoBase64'] != null) {
        setState(() => _base64Photo = doc.data()!['profilePhotoBase64']);
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    final pickedBytes = await picked.readAsBytes();

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ImageCropScreen(imageBytes: pickedBytes),
        fullscreenDialog: true,
      ),
    );
    if (croppedBytes == null) return;

    setState(() => _uploadingPhoto = true);

    try {
      final compressed = await FlutterImageCompress.compressWithList(
        croppedBytes,
        minHeight: 300,
        minWidth: 300,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (compressed.length > 900000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image too large. Please choose a smaller image.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _uploadingPhoto = false);
        return;
      }

      final base64String = base64Encode(compressed);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'profilePhotoBase64': base64String},
        SetOptions(merge: true),
      );

      setState(() {
        _base64Photo = base64String;
        _uploadingPhoto = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo updated'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadingPhoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update(
        {'profilePhotoBase64': FieldValue.delete()},
      );
      setState(() => _base64Photo = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Photo removed'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _savingName = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user!.updateDisplayName(name);
      await user.reload();
      if (mounted) setState(() => _savingName = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile saved'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      setState(() => _savingName = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadPhoto();
              },
            ),
            if (_base64Photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removePhoto();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final freshUser = FirebaseAuth.instance.currentUser;
    final email = freshUser?.email ?? '';
    final isGoogleUser = freshUser?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    final isEmailUser = freshUser?.providerData.any((p) => p.providerId == 'password') ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

    // Avatar image
    ImageProvider? avatarImage;
    if (_base64Photo != null) {
      avatarImage = MemoryImage(base64Decode(_base64Photo!));
    } else if (freshUser?.photoURL != null) {
      avatarImage = NetworkImage(freshUser!.photoURL!);
    }

    final displayName = freshUser?.displayName ?? '';
    final initials = displayName.isNotEmpty
        ? displayName.trim().split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join()
        : email.isNotEmpty ? email[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [

          // ── Avatar Card ────────────────────────────────────────────────
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: _blue.withValues(alpha: 0.15),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: _blue,
                          ),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingPhoto ? null : _showPhotoOptions,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: _blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _uploadingPhoto
                                ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.camera_alt, color: Colors.white, size: 17),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _uploadingPhoto ? null : _showPhotoOptions,
                    child: const Text('Change Photo', style: TextStyle(color: _blue)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── ACCOUNT INFO Card ──────────────────────────────────────────
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Text(
                    'ACCOUNT INFO',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _blue,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),

                // ── Name (editable inline) ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        labelStyle: TextStyle(fontSize: 13, color: Colors.grey),
                        floatingLabelStyle: TextStyle(
                          fontSize: 12,
                          color: _blue,
                          fontWeight: FontWeight.w600,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        suffixIcon: Icon(Icons.edit_outlined, color: _blue, size: 18),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Email (read-only) ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email Address',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          email.isNotEmpty ? email : 'Not set',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Sign-in Method (read-only) ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Sign-in Method',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isGoogleUser
                                  ? Icons.g_mobiledata_rounded
                                  : Icons.email_outlined,
                              color: _blue,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isGoogleUser
                                  ? 'Google Account'
                                  : isEmailUser
                                  ? 'Email & Password'
                                  : 'Unknown',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Save Changes Button ────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _savingName ? null : _saveChanges,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _savingName
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : const Text(
                'Save Changes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
