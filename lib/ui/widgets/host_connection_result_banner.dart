import 'package:flutter/material.dart';

import '../../domain/models/host_connection_result.dart';
import '../theme/script_vault_style.dart';

class HostConnectionResultBanner extends StatelessWidget {
  final HostConnectionResult result;

  const HostConnectionResultBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success
        ? ScriptVaultStyle.success
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.success ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ScriptVaultStyle.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
