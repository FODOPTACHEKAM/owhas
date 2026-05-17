import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../models/semester.dart';
import '../../../models/catalogue_course.dart';
import '../../../services/course_service.dart';
import '../../../theme.dart';
import '../widgets/catalogue_dialogs.dart';
import '../widgets/catalogue_empty_state.dart';
import '../widgets/catalogue_tiles.dart';

/// Refactored course-catalogue screen — build() ≤ 30 lines.
///
/// The existing [CourseCataloguePage] in `lib/pages/` is untouched
/// until routing is migrated in a later phase.
class CourseCatalogueScreen extends StatefulWidget {
  const CourseCatalogueScreen({super.key});

  @override
  State<CourseCatalogueScreen> createState() => _CourseCatalogueScreenState();
}

class _CourseCatalogueScreenState extends State<CourseCatalogueScreen> {
  List<Semester>        _semesters = [];
  List<CatalogueCourse> _courses   = [];
  bool                  _loading   = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final semesters = await CourseService.loadSemesters();
    final courses   = await CourseService.loadCourses();
    if (!mounted) return;
    setState(() { _semesters = semesters; _courses = courses; _loading = false; });
  }

  List<CatalogueCourse> _coursesFor(String semesterId) =>
      _courses.where((c) => c.semesterId == semesterId).toList();

  // ── Semester actions ──────────────────────────────────────────────────────────

  Future<void> _addSemester() async {
    final result = await CatalogueDialogs.showSemesterDialog(context);
    if (result == null || !mounted) return;
    await CourseService.saveSemester(result);
    await _load();
  }

  Future<void> _editSemester(Semester semester) async {
    final result = await CatalogueDialogs.showSemesterDialog(context, existing: semester);
    if (result == null || !mounted) return;
    await CourseService.saveSemester(result);
    await _load();
  }

  Future<void> _deleteSemester(Semester semester) async {
    final count     = _coursesFor(semester.id).length;
    final confirmed = await CatalogueDialogs.showDeleteConfirm(
      context,
      title:   'Delete Semester',
      content: count > 0
          ? 'This will also delete $count course${count > 1 ? 's' : ''} '
            'in "${semester.label}". This cannot be undone.'
          : 'Delete "${semester.label}"?',
    );
    if (!confirmed || !mounted) return;
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

  // ── Course actions ────────────────────────────────────────────────────────────

  Future<void> _addCourse(Semester semester) async {
    final result = await CatalogueDialogs.showCourseDialog(context, semesterId: semester.id);
    if (result == null || !mounted) return;
    await CourseService.saveCourse(result);
    await _load();
  }

  Future<void> _editCourse(CatalogueCourse course) async {
    final result = await CatalogueDialogs.showCourseDialog(
      context, semesterId: course.semesterId, existing: course,
    );
    if (result == null || !mounted) return;
    await CourseService.saveCourse(result);
    await _load();
  }

  Future<void> _deleteCourse(CatalogueCourse course) async {
    final confirmed = await CatalogueDialogs.showDeleteConfirm(
      context,
      title:   'Delete Course',
      content: 'Delete "${course.name} (${course.code})"?',
    );
    if (!confirmed || !mounted) return;
    await CourseService.deleteCourse(course.id);
    await _load();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title:   const Text('Course Catalogue'),
        actions: [
          FilledButton.icon(
            onPressed: _addSemester,
            icon:      const Icon(Icons.add, size: 18),
            label:     const Text('Semester'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _semesters.isEmpty
              ? CatalogueEmptyState(onAddSemester: _addSemester)
              : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding:   const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      itemCount: _semesters.length,
      itemBuilder: (_, i) {
        final semester = _semesters[i];
        return SemesterTile(
          // KEY: ensures Flutter disposes old tile when semester list changes.
          key:            ValueKey(semester.id),
          semester:       semester,
          courses:        _coursesFor(semester.id),
          onSetActive:    () => _setActive(semester),
          onEdit:         () => _editSemester(semester),
          onDelete:       () => _deleteSemester(semester),
          onAddCourse:    () => _addCourse(semester),
          onEditCourse:   _editCourse,
          onDeleteCourse: _deleteCourse,
        );
      },
    );
  }
}
