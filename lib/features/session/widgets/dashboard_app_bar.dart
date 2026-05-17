import 'package:flutter/material.dart';

/// AppBar for the live-session dashboard.
///
/// All action callbacks are injected so the screen owns the logic.
class DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DashboardAppBar({
    super.key,
    required this.onBack,
    required this.onRefresh,
    required this.onShareReport,
    required this.onDownloadPdf,
    required this.onAddManual,
    required this.onSignature,
    required this.onEndSession,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onShareReport;
  final VoidCallback onDownloadPdf;
  final VoidCallback onAddManual;
  final VoidCallback onSignature;
  final VoidCallback onEndSession;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      title:       const Text('Live Session'),
      centerTitle: false,
      elevation:   0,
      backgroundColor: cs.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      actions: [
        IconButton(icon: const Icon(Icons.refresh),        tooltip: 'Refresh',       onPressed: onRefresh),
        IconButton(icon: const Icon(Icons.share_outlined), tooltip: 'Share Report',  onPressed: onShareReport),
        IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Download PDF', onPressed: onDownloadPdf),
        PopupMenuButton<String>(
          tooltip:    'More Actions',
          onSelected: (value) {
            switch (value) {
              case 'signature': onSignature();
              case 'add_manual': onAddManual();
              case 'end_session': onEndSession();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'signature',
                child: Row(children: [Icon(Icons.draw, size: 20), SizedBox(width: 8), Text('Digital Signature')])),
            PopupMenuItem(value: 'add_manual',
                child: Row(children: [Icon(Icons.person_add, size: 20), SizedBox(width: 8), Text('Add Manual Student')])),
            PopupMenuDivider(),
            PopupMenuItem(value: 'end_session',
                child: Row(children: [Icon(Icons.stop, size: 20, color: Colors.red), SizedBox(width: 8), Text('End Session', style: TextStyle(color: Colors.red))])),
          ],
        ),
      ],
    );
  }
}
