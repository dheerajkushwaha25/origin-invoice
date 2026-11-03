import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezinvoice/screens/clients/new_client_screen.dart';
import 'package:ezinvoice/screens/clients/client_detail_screen.dart';
import 'package:ezinvoice/providers/client_provider.dart';
import 'package:ezinvoice/models/client.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  bool _isSearching = false;

  static const _metaColorLight = Color(0xFF444444);
  static const _metaColorDark = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredClients = query.isEmpty
          ? _allClients
          : _allClients.where((c) =>
      c.businessName.toLowerCase().contains(query) ||
          (c.gstNumber?.toLowerCase().contains(query) ?? false)).toList();
    });
  }

  Future<void> _onRefresh() async {
    try {
      await ref.refresh(clientListProvider.future);
      if (mounted) setState(() { _allClients = []; _filteredClients = []; });
    } catch (_) {}
  }

  String _getInitials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsyncValue = ref.watch(clientListProvider);

    clientsAsyncValue.whenData((clients) {
      // Always sync when provider changes — catches optimistic deletes instantly
      if (_allClients != clients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _allClients = clients;
              if (!_isSearching) _filteredClients = _allClients;
              else _onSearchChanged();
            });
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // AppScaffold handles switching to Home tab
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search clients...',
              border: InputBorder.none,
            ),
          )
              : const Text('Clients'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) { _searchController.clear(); _filteredClients = _allClients; }
                });
              },
            ),
          ],
        ),
        body: clientsAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error loading clients: $e')),
          data: (clients) {
            if (clients.isEmpty && !_isSearching) {
              return RefreshIndicator(
                onRefresh: _onRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 200),
                    Center(child: Text('No clients yet. Tap "New Client" to add one.')),
                  ],
                ),
              );
            }

            if (_isSearching && _filteredClients.isEmpty) {
              return Center(child: Text('No results for "${_searchController.text}"', style: const TextStyle(color: Colors.grey)));
            }

            return RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                // ✅ FIXED: matched padding to All Bills screen (horizontal: 12)
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final client = _filteredClients[index];
                  final initials = _getInitials(client.businessName);
                  final hasGst = client.gstNumber != null && client.gstNumber!.isNotEmpty;

                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  return Card(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isDark ? const BorderSide(color: Color(0xFF2C2C2C), width: 1) : BorderSide.none,
                    ),
                    elevation: isDark ? 0 : 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.12),
                        child: Text(initials, style: const TextStyle(color: Color(0xFF1877F2), fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      title: Text(client.businessName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      subtitle: hasGst
                          ? Text('GST: ${client.gstNumber}', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? _metaColorDark : _metaColorLight))
                          : Text('No GST number', style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.dark ? _metaColorDark : _metaColorLight)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ClientDetailScreen(clientName: client.businessName)),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        // ✅ FIXED: matched FAB style exactly to All Bills screen
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NewClientScreen(clientData: null)),
          ),
          icon: const Icon(Icons.add_circle),
          label: const Text('New Client'),
        ),
      ),
    );
  }
}
