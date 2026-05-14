import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/server_config.dart';

class QrCodeSection extends StatefulWidget {
  final String? sessionToken;

  const QrCodeSection({
    super.key,
    this.sessionToken,
  });

  @override
  State<QrCodeSection> createState() => _QrCodeSectionState();
}

class _QrCodeSectionState extends State<QrCodeSection> {
  String? _dynamicQrUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDynamicQrUrl();
  }

  Future<void> _fetchDynamicQrUrl() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = await ServerConfig().getDynamicQrUrl();
      if (mounted) {
        setState(() {
          _dynamicQrUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _qrData {
    final baseUrl = _dynamicQrUrl ?? ServerConfig().baseQrUrl;
    return (widget.sessionToken != null && widget.sessionToken!.isNotEmpty)
        ? '$baseUrl?s=${widget.sessionToken}'
        : baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final qrSize = isNarrow ? 140.0 : 120.0;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            const BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.04),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: qrSize,
                                height: qrSize,
                                child: const CircularProgressIndicator(),
                              )
                            : QrImageView(
                                data: _qrData,
                                size: qrSize,
                              ),
                      ),
                      const SizedBox(height: 8),
                      _buildOnlineHint(context),
                      const SizedBox(height: 16),
                      _buildDetails(context),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                const BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.04),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: qrSize,
                                    height: qrSize,
                                    child: const CircularProgressIndicator(),
                                  )
                                : QrImageView(
                                    data: _qrData,
                                    size: qrSize,
                                  ),
                          ),
                          const SizedBox(height: 8),
                          _buildOnlineHint(context),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDetails(context)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOnlineHint(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.language,
          size: 13,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          'For ONLINE type  OWHAS.ORG',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(BuildContext context) {
    // Show warning only when the dynamic URL fetch failed and we fell back to the
    // hardcoded default IP — not based on which IP the URL contains.
    final isWrongIp = _dynamicQrUrl == null && !_isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Student Registration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              tooltip: 'Refresh QR URL',
              onPressed: _fetchDynamicQrUrl,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Students scan this QR code to register.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isWrongIp
                ? Colors.orange.withAlpha(30)
                : Theme.of(context).colorScheme.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: isWrongIp
                ? Border.all(color: Colors.orange, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isWrongIp ? Icons.warning_amber : Icons.link,
                size: 16,
                color: isWrongIp
                    ? Colors.orange[800]
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _qrData,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isWrongIp
                        ? Colors.orange[800]
                        : Theme.of(context).colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (isWrongIp)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Could not auto-detect server URL — using default IP. Tap Refresh once connected to the hotspot.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.orange[800],
              ),
            ),
          ),
      ],
    );
  }
}