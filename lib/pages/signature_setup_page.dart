import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/signature_service.dart';
import '../widgets/signature_pad.dart';
import '../theme.dart';

/// Page for the lecturer to draw, preview, save, or clear their digital signature.
/// The signature is embedded into generated PDF attendance reports.
class SignatureSetupPage extends StatefulWidget {
  const SignatureSetupPage({super.key});

  @override
  State<SignatureSetupPage> createState() => _SignatureSetupPageState();
}

class _SignatureSetupPageState extends State<SignatureSetupPage> {
  final GlobalKey<SignaturePadState> _signaturePadKey = GlobalKey();
  final _lecturerNameController = TextEditingController();
  Uint8List? _savedSignature;
  String? _savedLecturerName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  @override
  void dispose() {
    _lecturerNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final bytes = await SignatureService.loadSignature();
    final name = await SignatureService.loadLecturerName();
    if (mounted) {
      setState(() {
        _savedSignature = bytes;
        _savedLecturerName = name;
        if (name != null) {
          _lecturerNameController.text = name;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSignature() async {
    final lecturerName = _lecturerNameController.text.trim();
    if (lecturerName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter your name')),
        );
      }
      return;
    }

    final pngBytes = await _signaturePadKey.currentState?.exportToPng();
    if (pngBytes == null || pngBytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please draw a signature first')),
        );
      }
      return;
    }

    final nameSuccess = await SignatureService.saveLecturerName(lecturerName);
    final sigSuccess = await SignatureService.saveSignature(pngBytes);

    if (mounted) {
      if (nameSuccess && sigSuccess) {
        setState(() {
          _savedSignature = pngBytes;
          _savedLecturerName = lecturerName;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature and name saved successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save signature or name'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearSignature() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Signature?'),
        content: const Text(
          'This will remove your saved signature and name. You will need to enter them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final nameCleared = await SignatureService.clearLecturerName();
    final sigCleared = await SignatureService.clearSignature();

    if (mounted) {
      if (nameCleared && sigCleared) {
        _signaturePadKey.currentState?.clear();
        _lecturerNameController.clear();
        setState(() {
          _savedSignature = null;
          _savedLecturerName = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature and name cleared')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to clear signature'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
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
                  Text(
                    'Draw Your Signature',
                    style: context.textStyles.headlineMedium?.bold,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your signature will be embedded at the bottom of every attendance PDF report you generate.',
                    style: context.textStyles.bodyMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Lecturer Name
                  TextFormField(
                    controller: _lecturerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Lecturer Name',
                      hintText: 'e.g., Dr. John Smith',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Signature Pad
                  SignaturePad(
                    key: _signaturePadKey,
                    height: 220,
                    penColor: Colors.black,
                    penStrokeWidth: 3.0,
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Pad actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _signaturePadKey.currentState?.clear(),
                          icon: const Icon(Icons.clear),
                          label: const Text('Clear Pad'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saveSignature,
                          icon: const Icon(Icons.save),
                          label: const Text('Save Signature'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Saved signature preview
                  if (_savedSignature != null) ...[
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved Signature',
                                style: context.textStyles.titleMedium?.semiBold,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              if (_savedLecturerName != null)
                                Text(
                                  'Lecturer: $_savedLecturerName',
                                  style: context.textStyles.bodySmall?.withColor(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              Text(
                                'This signature will appear on all PDF reports.',
                                style: context.textStyles.bodySmall?.withColor(
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _clearSignature,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove saved signature',
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Image.memory(
                          _savedSignature!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

