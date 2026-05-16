import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../services/signature_service.dart';
import '../../../theme.dart';
import '../../../widgets/signature_pad.dart';
import '../widgets/signature_widgets.dart';

/// Refactored signature-setup screen — build() ≤ 45 lines.
///
/// The existing [SignatureSetupPage] in `lib/pages/` is untouched
/// until routing is migrated in a later phase.
class SignatureSetupScreen extends StatefulWidget {
  const SignatureSetupScreen({super.key});

  @override
  State<SignatureSetupScreen> createState() => _SignatureSetupScreenState();
}

class _SignatureSetupScreenState extends State<SignatureSetupScreen> {
  final GlobalKey<SignaturePadState>  _padKey     = GlobalKey();
  final TextEditingController        _nameCtrl   = TextEditingController();

  Uint8List? _savedSignature;
  String?    _savedName;
  bool       _isLoading = true;

  @override
  void initState() { super.initState(); _loadSavedData(); }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _loadSavedData() async {
    final bytes = await SignatureService.loadSignature();
    final name  = await SignatureService.loadLecturerName();
    if (!mounted) return;
    setState(() {
      _savedSignature = bytes;
      _savedName      = name;
      if (name != null) _nameCtrl.text = name;
      _isLoading = false;
    });
  }

  Future<void> _saveSignature() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
      }
      return;
    }
    final png = await _padKey.currentState?.exportToPng();
    if (png == null || png.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please draw a signature first')),
        );
      }
      return;
    }
    final ok = await SignatureService.saveLecturerName(name) &&
               await SignatureService.saveSignature(png);
    if (!mounted) return;
    if (ok) {
      setState(() { _savedSignature = png; _savedName = name; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature and name saved successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Failed to save signature or name'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title:   const Text('Clear Signature?'),
        content: const Text(
          'This will remove your saved signature and name. You will need to enter them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final ok = await SignatureService.clearLecturerName() &&
               await SignatureService.clearSignature();
    if (!mounted) return;
    if (ok) {
      _padKey.currentState?.clear();
      _nameCtrl.clear();
      setState(() { _savedSignature = null; _savedName = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature and name cleared')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Failed to clear signature'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.navigateTo(RouteConstants.dashboard),
        ),
        title: const Text('Digital Signature'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Draw Your Signature',
                      style: context.textStyles.headlineMedium?.bold),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your signature will be embedded at the bottom of every attendance PDF report you generate.',
                    style: context.textStyles.bodyMedium
                        ?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SignatureFormSection(
                    nameController: _nameCtrl,
                    padKey:         _padKey,
                    onSave:         _saveSignature,
                    onClearPad:     () => _padKey.currentState?.clear(),
                  ),
                  if (_savedSignature != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    SavedSignaturePreview(
                      bytes:        _savedSignature!,
                      lecturerName: _savedName,
                      onClear:      _clearSignature,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
