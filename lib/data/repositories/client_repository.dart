// lib/data/repositories/client_repository.dart
//
// ✅ FIREBASE VERSION — replaces the SQLite ClientRepository.
// Public API is identical — client_provider.dart needs zero changes.

import 'package:ezinvoice/data/firebase/firebase_service.dart';
import 'package:ezinvoice/models/client.dart';

class ClientRepository {
  final _fb = FirebaseService.instance;

  Future<int> insertOrUpdate(Client client) async {
    await _fb.insertOrUpdateClient(client);
    return 1;
  }

  Future<List<Client>> getAllClients() async {
    return _fb.getAllClients();
  }

  Future<Client?> getClientById(String id) async {
    return _fb.getClientById(id);
  }

  Future<int> deleteClient(String id) async {
    await _fb.deleteClient(id);
    return 1;
  }

  Future<int> updateClient(Client client) async {
    return insertOrUpdate(client);
  }
}
