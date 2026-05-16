import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../theme.dart';

typedef DownloadCallback = Future<void> Function(String sessionId, String courseName);

/// Expandable card for a single cloud attendance session.
class CloudSessionCard extends StatelessWidget {
  const CloudSessionCard({
    super.key,
    required this.session,
    required this.onDownload,
  });

  final Map<String, dynamic> session;
  final DownloadCallback     onDownload;

  @override
  Widget build(BuildContext context) {
    final cs            = Theme.of(context).colorScheme;
    final isActive      = session['isActive'] == true;
    final courseName    = session['courseName'] as String? ?? 'Untitled';
    final courseCode    = session['courseCode'] as String?;
    final sessionNumber = session['sessionNumber'] ?? 1;
    final total         = session['totalAttendees'] ?? 0;
    final verified      = session['verifiedCount']  ?? 0;
    final startTime     = _formatDate(session['startTime'] as String?);
    final sessionPin    = session['sessionPin'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ExpansionTile(
        leading: Container(
          width:  48,
          height: 48,
          decoration: BoxDecoration(
            color: isActive ? Colors.green[100] : cs.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            isActive ? Icons.play_circle : Icons.check_circle,
            color: isActive ? Colors.green[700] : null,
          ),
        ),
        title:    Text(courseName, style: context.textStyles.titleMedium?.semiBold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (courseCode != null) Text('Code: $courseCode'),
            Text('Session #$sessionNumber • $startTime'),
          ],
        ),
        children: [
          Padding(
            padding: AppSpacing.paddingMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(icon: Icons.people,  label: 'Total',   value: total.toString(),              color: Colors.blue),
                    _StatChip(icon: Icons.verified, label: 'Verified', value: verified.toString(),           color: Colors.green),
                    _StatChip(icon: Icons.pending,  label: 'Pending',  value: (total - verified).toString(), color: Colors.orange),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (sessionPin != null) ...[
                  Container(
                    padding:    AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color:        Colors.grey[100],
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pin),
                        const SizedBox(width: AppSpacing.sm),
                        Text('PIN: $sessionPin', style: context.textStyles.titleMedium?.semiBold),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => onDownload(session['id'] as String, courseName),
                    icon:      const Icon(Icons.download),
                    label:     const Text('Download Records'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(String? isoDate) {
  if (isoDate == null) return 'Unknown';
  try {
    return DateFormat('MMM dd, yyyy - HH:mm').format(DateTime.parse(isoDate));
  } catch (_) {
    return isoDate;
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: context.textStyles.titleMedium?.semiBold.withColor(color)),
        Text(label, style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!)),
      ],
    );
  }
}
