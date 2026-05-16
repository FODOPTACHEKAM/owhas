import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../widgets/signature_pad.dart';

// ── Signature form section ────────────────────────────────────────────────────

/// Name field + signature pad canvas + Clear/Save button row.
class SignatureFormSection extends StatelessWidget {
  const SignatureFormSection({
    super.key,
    required this.nameController,
    required this.padKey,
    required this.onSave,
    required this.onClearPad,
  });

  final TextEditingController            nameController;
  final GlobalKey<SignaturePadState>     padKey;
  final VoidCallback                     onSave;
  final VoidCallback                     onClearPad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText:  'Lecturer Name',
            hintText:   'e.g., Dr. John Smith',
            border:     OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
          validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        SignaturePad(
          key:             padKey,
          height:          220,
          penColor:        Colors.black,
          penStrokeWidth:  3.0,
          backgroundColor: Colors.white,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onClearPad,
                icon:      const Icon(Icons.clear),
                label:     const Text('Clear Pad'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: onSave,
                icon:      const Icon(Icons.save),
                label:     const Text('Save Signature'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Saved signature preview ───────────────────────────────────────────────────

/// Divider + info row + signature thumbnail shown when a signature is saved.
class SavedSignaturePreview extends StatelessWidget {
  const SavedSignaturePreview({
    super.key,
    required this.bytes,
    required this.lecturerName,
    required this.onClear,
  });

  final Uint8List  bytes;
  final String?    lecturerName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  if (lecturerName != null)
                    Text(
                      'Lecturer: $lecturerName',
                      style: context.textStyles.bodySmall?.withColor(cs.primary),
                    ),
                  Text(
                    'This signature will appear on all PDF reports.',
                    style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon:      const Icon(Icons.delete_outline),
              tooltip:   'Remove saved signature',
              color:     cs.error,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height:     120,
          decoration: BoxDecoration(
            color:        Colors.white,
            border:       Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        ),
      ],
    );
  }
}
