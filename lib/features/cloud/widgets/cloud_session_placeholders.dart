import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Shown when the cloud sessions fetch fails.
class CloudErrorView extends StatelessWidget {
  const CloudErrorView({super.key, required this.error, required this.onRetry});

  final String       error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: AppSpacing.md),
            Text('Failed to load sessions', style: context.textStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: context.textStyles.bodyMedium?.withColor(Colors.red[700]!),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:      const Icon(Icons.refresh),
              label:     const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the user has no synced sessions yet.
class CloudEmptyView extends StatelessWidget {
  const CloudEmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.md),
            Text('No Cloud Sessions', style: context.textStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your synced sessions will appear here.\n'
              'Create a session while signed in to sync to the cloud.',
              style:     context.textStyles.bodyMedium?.withColor(Colors.grey[600]!),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
