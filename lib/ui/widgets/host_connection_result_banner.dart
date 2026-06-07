import 'package:flutter/material.dart';

import '../../domain/models/host_connection_result.dart';

class HostConnectionResultBanner extends StatelessWidget {
  final HostConnectionResult result;

  const HostConnectionResultBanner({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = result.success
        ? const Color(0xFF2E7D32)
        : Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(6),
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
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
