import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/semester.dart';
import '../models/catalogue_course.dart';
import '../services/course_service.dart';
import '../theme.dart';

class CourseCataloguePage extends StatefulWidget {
  const CourseCataloguePage({super.key});

  @override
  State<CourseCataloguePage> createState() => _CourseCataloguePageState();
}

class _CourseCataloguePageState extends State<CourseCataloguePage> {
  List<Semester> _semesters = [];
  List<CatalogueCourse> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final semesters = await CourseService.loadSemesters();
    final courses = await CourseService.loadCourses();
    if (!mounted) return;
    setState(() {
      _semesters = semesters;
      _courses = courses;
      _loading = false;
    });
  }

  List<CatalogueCourse> _coursesFor(String semesterId) =>
      _courses.where((c) => c.semesterId == semesterId).toList();

  // ── Semester actions ────────────────────────────────────────────────────────

  Future<void> _addSemester() async {
    final result = await _showSemesterDialog();
    if (result == null || !mounted) return;
    await CourseService.saveSemester(result);
    await _load();
  }

  Future<void> _editSemester(Semester semester) async {
    final result = await _showSemesterDialog(existing: semester);
    if (result == null || !mounted) return;
    await CourseService.saveSemester(result);
    await _load();
  }

  Future<void> _deleteSemester(Semester semester) async {
    final courseCount = _coursesFor(semester.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      // FIX: use the dialog's own context (dialogCtx) for Navigator.pop,
      // not the page's context. Mixing contexts from different render trees
      // causes "not in the same render tree" / "child._parent == this" errors.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text(
          courseCount > 0
              ? 'This will also delete $courseCount course${courseCount > 1 ? 's' : ''} '
                'in "${semester.label}". This cannot be undone.'
              : 'Delete "${semester.label}"?',
        ),
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
    );
    if (confirmed != true || !mounted) return;
    await CourseService.deleteSemester(semester.id);
    await _load();
  }

  Future<void> _setActive(Semester semester) async {
    if (semester.isActive) return;
    await CourseService.setActiveSemester(semester.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${semester.label}" set as active semester')),
      );
    }
  }

  // ── Course actions ──────────────────────────────────────────────────────────

  Future<void> _addCourse(Semester semester) async {
    final result = await _showCourseDialog(semesterId: semester.id);
    if (result == null || !mounted) return;
    await CourseService.saveCourse(result);
    await _load();
  }

  Future<void> _editCourse(CatalogueCourse course) async {
    final result = await _showCourseDialog(
      semesterId: course.semesterId,
      existing: course,
    );
    if (result == null || !mounted) return;
    await CourseService.saveCourse(result);
    await _load();
  }

  Future<void> _deleteCourse(CatalogueCourse course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      // FIX: same as _deleteSemester — use dialogCtx for Navigator.pop.
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text('Delete "${course.name} (${course.code})"?'),
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
    );
    if (confirmed != true || !mounted) return;
    await CourseService.deleteCourse(course.id);
    await _load();
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  Future<Semester?> _showSemesterDialog({Semester? existing}) async {
    final yearCtrl = TextEditingController(text: existing?.academicYear ?? '');
    int selectedNumber = existing?.number ?? 1;
    final formKey = GlobalKey<FormState>();

    return showDialog<Semester>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
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
                      hintText: 'e.g. 2025/2026',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: selectedNumber,
                    decoration: const InputDecoration(
                      labelText: 'Semester Number',
                      border: OutlineInputBorder(),
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
                          id: existing.id,
                          isActive: existing.isActive,
                          createdAt: existing.createdAt,
                        );
                  Navigator.pop(ctx, result);
                },
                child: Text(existing == null ? 'Add' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<CatalogueCourse?> _showCourseDialog({
    required String semesterId,
    CatalogueCourse? existing,
  }) async {
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
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Course Name *',
                    hintText: 'e.g. Database Systems',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Course Code *',
                    hintText: 'e.g. IFT3025',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: deptCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Department (optional)',
                    hintText: 'e.g. Computer Science',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: credCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Credits (optional)',
                    hintText: 'e.g. 3',
                    border: OutlineInputBorder(),
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
              final course = CourseService.buildCourse(
                semesterId: semesterId,
                name: nameCtrl.text,
                code: codeCtrl.text,
                department:
                    deptCtrl.text.trim().isEmpty ? null : deptCtrl.text,
                credits: credStr.isEmpty ? null : int.tryParse(credStr),
              );
              final result = existing == null
                  ? course
                  : course.copyWith(
                      id: existing.id,
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Course Catalogue'),
        actions: [
          FilledButton.icon(
            onPressed: _addSemester,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Semester'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _semesters.isEmpty
              ? _buildEmptyState()
              : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.3),
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
              style: context.textStyles.bodyMedium?.withColor(
                Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: _addSemester,
              icon: const Icon(Icons.add),
              label: const Text('Add First Semester'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      itemCount: _semesters.length,
      itemBuilder: (_, i) {
        final semester = _semesters[i];
        return _SemesterTile(
          // KEY: ensures Flutter disposes old tile when semester list changes,
          // preventing ExpansionTile animation state from bleeding across rows.
          key: ValueKey(semester.id),
          semester: semester,
          courses: _coursesFor(semester.id),
          onSetActive: () => _setActive(semester),
          onEdit: () => _editSemester(semester),
          onDelete: () => _deleteSemester(semester),
          onAddCourse: () => _addCourse(semester),
          onEditCourse: _editCourse,
          onDeleteCourse: _deleteCourse,
        );
      },
    );
  }
}

// ── Semester Tile ─────────────────────────────────────────────────────────────

class _SemesterTile extends StatelessWidget {
  final Semester semester;
  final List<CatalogueCourse> courses;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddCourse;
  final ValueChanged<CatalogueCourse> onEditCourse;
  final ValueChanged<CatalogueCourse> onDeleteCourse;

  const _SemesterTile({
    super.key,
    required this.semester,
    required this.courses,
    required this.onSetActive,
    required this.onEdit,
    required this.onDelete,
    required this.onAddCourse,
    required this.onEditCourse,
    required this.onDeleteCourse,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = semester.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: isActive ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: isActive ? cs.primary : cs.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isActive,
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    semester.label,
                    style: context.textStyles.titleMedium?.semiBold,
                  ),
                  if (courses.isNotEmpty)
                    Text(
                      '${courses.length} course${courses.length > 1 ? 's' : ''}',
                      style: context.textStyles.bodySmall
                          ?.withColor(cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onSetActive,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? cs.primary.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? cs.primary : cs.outlineVariant,
                  ),
                ),
                child: Text(
                  isActive ? '● Active' : 'Set Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit semester',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
              tooltip: 'Delete semester',
              onPressed: onDelete,
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          if (courses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.lg,
              ),
              child: Text(
                'No courses yet. Add one below.',
                style: context.textStyles.bodySmall
                    ?.withColor(cs.onSurfaceVariant),
              ),
            ),
          ...courses.map(
            (c) => _CourseTile(
              // KEY: prevents course data/render state from being mismatched
              // when the list grows or shrinks after add/delete operations.
              key: ValueKey(c.id),
              course: c,
              onEdit: () => onEditCourse(c),
              onDelete: () => onDeleteCourse(c),
            ),
          ),
          InkWell(
            onTap: onAddCourse,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Add Course',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course Tile ───────────────────────────────────────────────────────────────

class _CourseTile extends StatelessWidget {
  final CatalogueCourse course;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CourseTile({
    super.key,
    required this.course,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 0,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  course.name,
                  style: context.textStyles.bodyMedium?.semiBold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  course.code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          subtitle: (course.department != null || course.credits != null)
              ? Text(
                  [
                    if (course.department != null) course.department!,
                    if (course.credits != null) '${course.credits} credits',
                  ].join('  ·  '),
                  style: context.textStyles.bodySmall
                      ?.withColor(cs.onSurfaceVariant),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit',
                onPressed: onEdit,
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, size: 16, color: cs.error),
                tooltip: 'Delete',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: AppSpacing.md,
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}
