import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Card that prompts the lecturer to load a previous session file.
class UploadPreviousCard extends StatelessWidget {
  const UploadPreviousCard({
    super.key,
    required this.isUploaded,
    required this.onUpload,
  });

  final bool isUploaded;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isUploaded ? Icons.check_circle : Icons.upload_file,
                  color: isUploaded ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Upload Previous Session (Optional)',
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Load previous attendance data to maintain cumulative totals. '
              'Supports Excel (.xlsx, .xls) and PDF (.pdf) files.',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(onPressed: onUpload, child: const Text('Choose File (Excel or PDF)')),
          ],
        ),
      ),
    );
  }
}

/// Lecturer name input that persists the value on focus-out.
class LecturerNameField extends StatelessWidget {
  const LecturerNameField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.storedName,
    required this.onClearSaved,
  });

  final TextEditingController controller;
  final FocusNode            focusNode;
  final String?              storedName;
  final VoidCallback         onClearSaved;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:           controller,
      focusNode:            focusNode,
      textCapitalization:   TextCapitalization.words,
      decoration: InputDecoration(
        labelText:    'Lecturer Name',
        hintText:     'e.g. Dr. John Smith',
        helperText:   storedName != null
            ? 'Pre-filled from your last session'
            : 'Will be saved for future sessions',
        border:       const OutlineInputBorder(),
        prefixIcon:   const Icon(Icons.person),
        suffixIcon:   storedName != null
            ? IconButton(
                icon:    const Icon(Icons.close, size: 18),
                tooltip: 'Clear saved name',
                onPressed: onClearSaved,
              )
            : null,
      ),
      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
    );
  }
}

/// Submit button that shows a spinner while a session is being created.
class StartSessionButton extends StatelessWidget {
  const StartSessionButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
  });

  final VoidCallback onPressed;
  final bool         isLoading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Padding(
        padding: AppSpacing.verticalMd,
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Start Session'),
      ),
    );
  }
}
