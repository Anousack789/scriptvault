import 'package:flutter/material.dart';

import '../../../domain/models/host_entry.dart';

class HostSelector extends StatelessWidget {
  final String value;
  final List<HostEntry> hosts;
  final ValueChanged<String> onChanged;
  final VoidCallback onManageHosts;

  const HostSelector({
    super.key,
    required this.value,
    required this.hosts,
    required this.onChanged,
    required this.onManageHosts,
  });

  @override
  Widget build(BuildContext context) {
    final knownHostIds = hosts.map((host) => host.id).toSet();
    final selectedValue = value.isEmpty || knownHostIds.contains(value)
        ? value
        : '__legacy_host__';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: selectedValue,
            decoration: const InputDecoration(
              labelText: 'Host',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Local machine')),
              for (final host in hosts)
                DropdownMenuItem(
                  value: host.id,
                  child: Text(
                    '${host.name} (${host.destination})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (selectedValue == '__legacy_host__')
                DropdownMenuItem(
                  value: selectedValue,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (next) {
              if (next == null || next == '__legacy_host__') return;
              onChanged(next);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Manage hosts',
          icon: const Icon(Icons.dns_outlined),
          onPressed: onManageHosts,
        ),
      ],
    );
  }
}
