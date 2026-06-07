import 'package:flutter/material.dart';

import '../../../domain/models/host_entry.dart';

class HostsSidebar extends StatelessWidget {
  final List<HostEntry> hosts;
  final String? selectedHostId;
  final bool isBusy;
  final VoidCallback onNewHost;
  final ValueChanged<HostEntry> onHostSelected;

  const HostsSidebar({
    super.key,
    required this.hosts,
    required this.selectedHostId,
    required this.isBusy,
    required this.onNewHost,
    required this.onHostSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF252526),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 56,
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2D2D30))),
            ),
            child: Row(
              children: [
                const Icon(Icons.dns_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hosts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'New host',
                  onPressed: isBusy ? null : onNewHost,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: hosts.isEmpty
                ? const Center(child: Text('No hosts found.'))
                : ListView.builder(
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return ListTile(
                        selected: host.id == selectedHostId,
                        leading: const Icon(Icons.computer_outlined),
                        title: Text(
                          host.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          host.destination,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: isBusy ? null : () => onHostSelected(host),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
