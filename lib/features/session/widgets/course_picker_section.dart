import 'package:flutter/material.dart';
import '../../../models/semester.dart';
import '../../../models/catalogue_course.dart';
import '../../../theme.dart';

/// Two read-only fields for semester and course selection.
///
/// The parent screen owns the picker dialogs — this widget just surfaces
/// the current selection and fires the [onSemesterTap] / [onCourseTap]
/// callbacks when the user taps.
class CoursePicker extends StatelessWidget {
  const CoursePicker({
    super.key,
    required this.semesterController,
    required this.courseController,
    required this.selectedSemester,
    required this.selectedCourse,
    required this.hasCourses,
    required this.onSemesterTap,
    required this.onCourseTap,
  });

  final TextEditingController semesterController;
  final TextEditingController courseController;
  final Semester?             selectedSemester;
  final CatalogueCourse?      selectedCourse;
  final bool                  hasCourses;
  final VoidCallback?         onSemesterTap;
  final VoidCallback?         onCourseTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: semesterController,
          readOnly:   true,
          onTap:      onSemesterTap,
          decoration: const InputDecoration(
            labelText:   'Semester',
            hintText:    'Tap to select semester',
            border:      OutlineInputBorder(),
            prefixIcon:  Icon(Icons.calendar_view_month_outlined),
            suffixIcon:  Icon(Icons.arrow_drop_down),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: courseController,
          readOnly:   true,
          onTap:      hasCourses ? onCourseTap : null,
          decoration: InputDecoration(
            labelText:  'Select Course',
            hintText:   hasCourses ? 'Tap to select course' : null,
            border:     const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.book_outlined),
            suffixIcon: hasCourses ? const Icon(Icons.arrow_drop_down) : null,
            helperText: selectedSemester == null
                ? 'Pick a semester first'
                : !hasCourses
                    ? 'No courses in this semester — add some in the Catalogue'
                    : 'Name and code will be filled automatically',
          ),
        ),
        if (selectedCourse?.department != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: 12),
            child: Text(
              '${selectedCourse!.department}'
              '${selectedCourse!.credits != null ? '  ·  ${selectedCourse!.credits} credits' : ''}',
              style: context.textStyles.bodySmall?.withColor(cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Shown instead of [CoursePicker] when no semesters are configured yet.
class NoCatalogueNotice extends StatelessWidget {
  const NoCatalogueNotice({super.key, required this.onGoToCatalogue});

  final VoidCallback onGoToCatalogue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color:        cs.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border:       Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onSecondaryContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No courses configured. Visit the Course Catalogue to add your '
              "institution's courses for quick selection.",
              style: context.textStyles.bodySmall?.withColor(cs.onSecondaryContainer),
            ),
          ),
          TextButton(onPressed: onGoToCatalogue, child: const Text('Go')),
        ],
      ),
    );
  }
}

/// Dialog body for semester selection.
class SemesterPickerDialog extends StatelessWidget {
  const SemesterPickerDialog({
    super.key,
    required this.semesters,
    this.selectedId,
  });

  final List<Semester> semesters;
  final String?        selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SimpleDialog(
      title: const Text('Select Semester'),
      children: semesters.map((s) {
        final isSelected = s.id == selectedId;
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, s),
          child: Row(
            children: [
              Expanded(
                child: Text(s.label,
                    style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
              ),
              if (s.isActive)
                Container(
                  margin:  const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer, borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Active',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer)),
                ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.check, size: 16, color: cs.primary),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Dialog body for course selection within the chosen semester.
class CoursePickerDialog extends StatelessWidget {
  const CoursePickerDialog({
    super.key,
    required this.courses,
    this.selectedId,
  });

  final List<CatalogueCourse> courses;
  final String?               selectedId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SimpleDialog(
      title: const Text('Select Course'),
      children: courses.map((c) {
        final isSelected = c.id == selectedId;
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(context, c),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(c.name,
                        style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                    if (c.department != null)
                      Text(c.department!,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: cs.primaryContainer, borderRadius: BorderRadius.circular(4)),
                child: Text(c.code,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer)),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.check, size: 16, color: cs.primary),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
