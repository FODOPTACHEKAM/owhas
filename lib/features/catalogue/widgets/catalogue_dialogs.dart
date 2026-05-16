import 'package:flutter/material.dart';
import '../../../models/semester.dart';
import '../../../models/catalogue_course.dart';
import '../../../services/course_service.dart';
import '../../../theme.dart';

/// Static dialog helpers for the course-catalogue feature.
abstract final class CatalogueDialogs {

  // ── Delete confirm ───────────────────────────────────────────────────────────

  static Future<bool> showDeleteConfirm(
    BuildContext context, {
    required String title,
    required String content,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogCtx).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Semester dialog ──────────────────────────────────────────────────────────

  static Future<Semester?> showSemesterDialog(
    BuildContext context, {
    Semester? existing,
  }) {
    final yearCtrl      = TextEditingController(text: existing?.academicYear ?? '');
    int selectedNumber  = existing?.number ?? 1;
    final formKey       = GlobalKey<FormState>();

    return showDialog<Semester>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Add Semester' : 'Edit Semester'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year',
                    hintText:  'e.g. 2025/2026',
                    border:    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  // ignore: deprecated_member_use
                  value:       selectedNumber,
                  decoration:  const InputDecoration(
                    labelText: 'Semester Number',
                    border:    OutlineInputBorder(),
                  ),
                  items: [1, 2, 3]
                      .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text('Semester $n'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDlg(() => selectedNumber = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final semester = CourseService.buildSemester(
                  academicYear: yearCtrl.text.trim(),
                  number: selectedNumber,
                );
                final result = existing == null
                    ? semester
                    : semester.copyWith(
                        id:        existing.id,
                        isActive:  existing.isActive,
                        createdAt: existing.createdAt,
                      );
                Navigator.pop(ctx, result);
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Course dialog ────────────────────────────────────────────────────────────

  static Future<CatalogueCourse?> showCourseDialog(
    BuildContext context, {
    required String semesterId,
    CatalogueCourse? existing,
  }) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final deptCtrl = TextEditingController(text: existing?.department ?? '');
    final credCtrl = TextEditingController(
      text: existing?.credits?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();

    return showDialog<CatalogueCourse>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Course' : 'Edit Course'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller:          nameCtrl,
                  textCapitalization:  TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Course Name *',
                    hintText:  'e.g. Database Systems',
                    border:    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller:         codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Course Code *',
                    hintText:  'e.g. IFT3025',
                    border:    OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller:         deptCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Department (optional)',
                    hintText:  'e.g. Computer Science',
                    border:    OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller:   credCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Credits (optional)',
                    hintText:  'e.g. 3',
                    border:    OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v.trim()) == null) return 'Must be a number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final credStr = credCtrl.text.trim();
              final course  = CourseService.buildCourse(
                semesterId: semesterId,
                name:       nameCtrl.text,
                code:       codeCtrl.text,
                department: deptCtrl.text.trim().isEmpty ? null : deptCtrl.text,
                credits:    credStr.isEmpty ? null : int.tryParse(credStr),
              );
              final result = existing == null
                  ? course
                  : course.copyWith(
                      id:        existing.id,
                      createdAt: existing.createdAt,
                    );
              Navigator.pop(ctx, result);
            },
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
