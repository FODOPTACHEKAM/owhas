import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceRecordTile extends StatelessWidget {
  final dynamic record;
  final VoidCallback? onRemove;

  const AttendanceRecordTile({
    super.key,
    required this.record,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = record.isVerified;
    final isManual = record.isManual as bool? ?? false;

    final statusColor = isManual
        ? Colors.grey
        : isVerified
            ? Colors.green
            : Colors.orange;

    final statusIcon = isManual
        ? Icons.person_outline
        : isVerified
            ? Icons.check_circle
            : Icons.pending;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(76)),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.studentName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Matricule: ${record.matricule}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isManual)
                  Text(
                    'Manual entry',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.connectionDurationMinutes} min',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                DateFormat('HH:mm').format(record.joinedAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.red),
              tooltip: 'Remove student',
              onPressed: onRemove,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}