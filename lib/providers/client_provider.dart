import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/models/client.dart';
import 'package:ezinvoice/data/repositories/client_repository.dart';

final clientRepositoryProvider = Provider((ref) => ClientRepository());

class ClientListNotifier extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() async {
    final repository = ref.watch(clientRepositoryProvider);
    return repository.getAllClients();
  }

  Future<void> addClient(Client client) async {
    state = const AsyncValue.loading();
    final repository = ref.read(clientRepositoryProvider);
    await repository.insertOrUpdate(client);
    state = await AsyncValue.guard(() => repository.getAllClients());
  }

  Future<void> deleteClient(String clientId) async {
    // Optimistic — remove from state instantly
    final currentList = state.valueOrNull ?? [];
    state = AsyncValue.data(currentList.where((c) => c.id != clientId).toList());
    // Delete from database in background
    final repository = ref.read(clientRepositoryProvider);
    await repository.deleteClient(clientId);
  }
}

final clientListProvider =
AsyncNotifierProvider<ClientListNotifier, List<Client>>(() {
  return ClientListNotifier();
});

final clientDetailProvider = FutureProvider.family<Client?, String>((ref, clientId) async {
  final repository = ref.watch(clientRepositoryProvider);
  return repository.getClientById(clientId);
});
