import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _base = http.Client();
  _GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _base.send(request);
  }
}

class DriveSyncService {
  final GoogleSignIn _signIn = GoogleSignIn(
    scopes: ['email', drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? get currentUser => _signIn.currentUser;
  Future<GoogleSignInAccount?> trySilentSignIn() async =>
      _signIn.currentUser ?? await _signIn.signInSilently();
  Future<void> signOut() => _signIn.signOut();

  Future<drive.DriveApi> _drive() async {
    final user = _signIn.currentUser ?? await _signIn.signInSilently();
    final account = user ?? await _signIn.signIn();
    if (account == null) throw Exception('Google sign-in canceled');
    final headers = await account.authHeaders;
    return drive.DriveApi(_GoogleAuthClient(headers));
  }

  Future<String> _ensureFolder({
    required drive.DriveApi api,
    required String name,
    String? parentId,
  }) async {
    final q = [
      "name = '$name'",
      "mimeType = 'application/vnd.google-apps.folder'",
      "trashed = false",
      if (parentId != null) "'$parentId' in parents",
    ].join(' and ');
    final found = await api.files.list(
      q: q,
      spaces: 'drive',
      $fields: 'files(id,name)',
      pageSize: 1,
    );
    if (found.files != null && found.files!.isNotEmpty) {
      return found.files!.first.id!;
    }
    final created = await api.files.create(
      drive.File()
        ..name = name
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentId != null ? [parentId] : null,
      $fields: 'id',
    );
    return created.id!;
  }

  Future<String> ensureFolderPath(List<String> segments) async {
    final api = await _drive();
    String? parent;
    for (final seg in segments) {
      parent = await _ensureFolder(api: api, name: seg, parentId: parent);
    }
    return parent!;
  }

  // Find a file with the given name inside a parent folder
  Future<String?> _findFileIdByName({
    required String parentFolderId,
    required String fileName,
  }) async {
    final api = await _drive();
    final res = await api.files.list(
      q: "name = '$fileName' and '$parentFolderId' in parents and trashed=false",
      $fields: 'files(id,name)',
      spaces: 'drive',
      pageSize: 1,
    );
    if (res.files != null && res.files!.isNotEmpty) {
      return res.files!.first.id!;
    }
    return null;
  }

  // Create new or replace existing invoice PDF with the same name
  Future<String> saveInvoicePdf({
    required String parentFolderId,
    required String fileName,
    required List<int> pdfBytes,
  }) async {
    final api = await _drive();
    final media = drive.Media(Stream.value(pdfBytes), pdfBytes.length);

    // Check if file exists in the folder
    final existingId = await _findFileIdByName(
      parentFolderId: parentFolderId,
      fileName: fileName,
    ); // search by name + parent [Drive files.list]
    if (existingId != null) {
      // Replace content (and keep the same name)
      final updated = await api.files.update(
        drive.File()..name = fileName,
        existingId,
        uploadMedia: media,
        $fields: 'id',
      ); // updates metadata/content [Drive files.update]
      return updated.id!;
    }

    // Otherwise, create fresh file in that folder
    final created = await api.files.create(
      drive.File()
        ..name = fileName
        ..mimeType = 'application/pdf'
        ..parents = [parentFolderId],
      uploadMedia: media,
      $fields: 'id',
    ); // create with parents so it’s visible in the folder [Drive files.list][Drive files.update]
    return created.id!;
  }

  // Keep the legacy method if other code still calls it
  Future<String> uploadInvoicePdf({
    required String parentFolderId,
    required String fileName,
    required List<int> pdfBytes,
  }) =>
      saveInvoicePdf(
        parentFolderId: parentFolderId,
        fileName: fileName,
        pdfBytes: pdfBytes,
      );
}
