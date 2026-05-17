import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notifiers/server_status_notifier.dart';

/// Soft circular gradient blob used as a decorative background element.
class AmbientBlob extends StatelessWidget {
  const AmbientBlob({super.key, required this.size, required this.color});
  final double size;
  final Color  color;

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape:    BoxShape.circle,
      gradient: RadialGradient(colors: [color, Colors.transparent]),
    ),
  );
}

/// Thin divider with an uppercase label — used to introduce role sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          color: onSurface.withValues(alpha: 0.35),
        )),
        const SizedBox(width: 10),
        Expanded(child: Divider(thickness: 0.5, color: onSurface.withValues(alpha: 0.1))),
      ],
    );
  }
}

/// Live server connection status bar with a refresh button.
class ServerStatusBanner extends StatelessWidget {
  const ServerStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerStatusNotifier>(
      builder: (_, notifier, __) {
        final status     = notifier.status;
        final isChecking = status == ServerConnectionStatus.checking;

        final (color, icon, label, sublabel) = switch (status) {
          ServerConnectionStatus.cloud => (
            const Color(0xFF27AE60),
            Icons.cloud_done_rounded,
            'Cloud Server',
            'owhas.org',
          ),
          ServerConnectionStatus.wifi => (
            const Color(0xFF1A3A6B),
            Icons.wifi_rounded,
            'Wi-Fi Server',
            _shortUrl(notifier.serverUrl),
          ),
          ServerConnectionStatus.none => (
            const Color(0xFFE67E22),
            Icons.wifi_off_rounded,
            'No Server Found',
            'Start server.js and reconnect',
          ),
          ServerConnectionStatus.checking => (
            const Color(0xFF8E9AAB),
            Icons.radar_rounded,
            'Detecting…',
            '',
          ),
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border:       Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              // Status dot
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecking ? color.withValues(alpha: 0.35) : color,
                ),
              ),
              const SizedBox(width: 6),
              Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              // Labels
              Expanded(
                child: Row(
                  children: [
                    Text(label,
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: color.withValues(alpha: 0.88),
                      ),
                    ),
                    if (sublabel.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text('·  $sublabel',
                          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.50)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Refresh — GestureDetector keeps the visual tiny; padding extends tap area
              isChecking
                  ? SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.2,
                        color: color.withValues(alpha: 0.5),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => notifier.refresh(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(Icons.refresh_rounded, size: 13,
                            color: color.withValues(alpha: 0.60)),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  static String _shortUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri?.host ?? url;
  }
}

/// Small pill badge with an icon and a text label.
class BadgePill extends StatelessWidget {
  const BadgePill({super.key, required this.icon, required this.label, required this.color});
  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.8),
        )),
      ],
    ),
  );
}
