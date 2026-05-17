import 'package:flutter/material.dart';

/// Shown in the body while the session-end teardown is running.
class SessionEndingSpinner extends StatelessWidget {
  const SessionEndingSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Ending session…'),
        ],
      ),
    );
  }
}

/// Shown when there is no active session (e.g. after navigating to the
/// dashboard with no session in progress).
class NoActiveSessionPlaceholder extends StatelessWidget {
  const NoActiveSessionPlaceholder({super.key, required this.onCreateSession});

  final VoidCallback onCreateSession;

  @override
  Widget build(BuildContext context) {
    final t  = Theme.of(context);
    final cs = t.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text('No Active Session', style: t.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Create a new session to start taking attendance',
            style: t.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreateSession,
            icon:  const Icon(Icons.add),
            label: const Text('Create Session'),
          ),
        ],
      ),
    );
  }
}

/// Orange warning strip shown when the local server is unreachable.
class ServerWarningBanner extends StatelessWidget {
  const ServerWarningBanner({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String        message;
  final VoidCallback  onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:   double.infinity,
      color:   Colors.orange[800],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          TextButton(
            onPressed: onRetry,
            style:     TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding:         const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
