import 'package:flutter/material.dart';

import '../../../domain/models/host_entry.dart';
import '../../theme/script_vault_style.dart';

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
    return Material(
      color: ScriptVaultStyle.appBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: ScriptVaultStyle.toolbarButtonStyle(),
                  onPressed: isBusy ? null : onNewHost,
                  icon: const Icon(Icons.add, size: 19),
                  label: const Text('New host'),
                ),
              ],
            ),
          ),
          Expanded(
            child: hosts.isEmpty
                ? Center(
                    child: Text(
                      'No hosts found.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ScriptVaultStyle.muted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: hosts.length,
                    itemBuilder: (context, index) {
                      final host = hosts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _hostCard(context, host),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hostCard(BuildContext context, HostEntry host) {
    final selected = host.id == selectedHostId;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isBusy ? null : () => onHostSelected(host),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: ScriptVaultStyle.panelDecoration(selected: selected),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ScriptVaultStyle.panelRaised,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ScriptVaultStyle.border),
                ),
                child: Icon(
                  host.authType == 'password'
                      ? Icons.password_outlined
                      : Icons.key_outlined,
                  size: 18,
                  color: selected
                      ? ScriptVaultStyle.primary
                      : ScriptVaultStyle.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ScriptVaultStyle.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      host.destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ScriptVaultStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.circle,
                size: 9,
                color: selected
                    ? ScriptVaultStyle.success
                    : ScriptVaultStyle.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
