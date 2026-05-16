import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Full-screen placeholder shown when no semesters have been created yet.
class CatalogueEmptyState extends StatelessWidget {
  const CatalogueEmptyState({super.key, required this.onAddSemester});

  final VoidCallback onAddSemester;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size:  72,
              color: cs.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No Semesters Yet',
              style: context.textStyles.titleLarge?.semiBold,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add semesters and their courses so lecturers can quickly\n'
              'select a course when starting a session.',
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onAddSemester,
              icon:      const Icon(Icons.add),
              label:     const Text('Add First Semester'),
            ),
          ],
        ),
      ),
    );
  }
}
