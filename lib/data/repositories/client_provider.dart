import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/data/repositories/client_repository.dart';

// AsyncNotifier to manage the state (list of clients)
class ClientListNotifier extends AsyncNotifier<List<Client>> {
  late final ClientRepository _repository;

  @override
  Future<List<Client>> build() async {
    // Initialize the repository instance
    _repository = ClientRepository();

    // Load all clients from the database when the provider is first created
    return _repository.getAllClients();
  }

  // ----------------------------------------------------
  // CLIENT ACTIONS (CRUD)
  // ----------------------------------------------------

  // Method to add a new client (or update an existing one)
  Future<void> addClient(Client client) async {
    // Set the state to loading while the operation is in progress
    state = const AsyncValue.loading();

    // Perform the database operation and wait for it to complete
    await _repository.insertOrUpdate(client);

    // Rebuild the state by fetching the entire updated list
    // (A more optimized approach would be to add the client locally, but this is safer)
    state = await AsyncValue.guard(() => _repository.getAllClients());
  }

  // Method to delete a client
  Future<void> deleteClient(String clientId) async {
    state = const AsyncValue.loading();

    // Perform the database operation
    await _repository.deleteClient(clientId);

    // Rebuild the state with the new list
    state = await AsyncValue.guard(() => _repository.getAllClients());
  }
}

// The main provider that exposes the client list state
final clientListProvider =
AsyncNotifierProvider<ClientListNotifier, List<Client>>(() {
  return ClientListNotifier();
});