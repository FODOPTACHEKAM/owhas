import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/semester.dart';
import '../../../models/catalogue_course.dart';
import '../../../services/course_service.dart';
import '../../../services/signature_service.dart';
import '../../../theme.dart';
import '../notifiers/session_state_notifier.dart';
import '../widgets/session_form_fields.dart';
import '../widgets/course_picker_section.dart';
import '../widgets/timing_fields_section.dart';

/// Session creation form — refactored from `pages/session_setup_page.dart`.
///
/// build() ≤ 60 lines; all business logic lives in the private State methods.
/// The existing `SessionSetupPage` in `lib/pages/` is untouched until routing
/// is migrated in a later phase.
class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  final _formKey                   = GlobalKey<FormState>();
  final _lecturerNameController    = TextEditingController();
  final _lecturerNameFocus         = FocusNode();
  final _semesterPickerController  = TextEditingController();
  final _coursePickerController    = TextEditingController();
  final _courseNameController      = TextEditingController();
  final _courseCodeController      = TextEditingController();
  final _gracePeriodController     = TextEditingController(text: '5');
  final _connectionTimeController  = TextEditingController(text: '10');
  final _maxAttendanceController   = TextEditingController(text: '200');
  final _durationController        = TextEditingController(text: '60');

  List<Semester>       _semesters    = [];
  List<CatalogueCourse> _allCourses  = [];
  Semester?            _selectedSemester;
  CatalogueCourse?     _selectedCourse;
  bool                 _hasUploadedPrevious = false;
  String?              _storedLecturerName;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _lecturerNameFocus.addListener(_onLecturerNameFocusChanged);
    _loadSavedLecturerName();
    _loadCatalogue();
  }

  @override
  void dispose() {
    _lecturerNameFocus.removeListener(_onLecturerNameFocusChanged);
    _lecturerNameFocus.dispose();
    for (final c in [
      _lecturerNameController, _semesterPickerController, _coursePickerController,
      _courseNameController, _courseCodeController, _gracePeriodController,
      _connectionTimeController, _maxAttendanceController, _durationController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Lecturer name helpers ─────────────────────────────────────────────────────

  Future<void> _loadSavedLecturerName() async {
    final saved = await SignatureService.loadLecturerName();
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() { _storedLecturerName = saved; _lecturerNameController.text = saved; });
    }
  }

  void _onLecturerNameFocusChanged() {
    if (_lecturerNameFocus.hasFocus) return;
    final name = _lecturerNameController.text.trim();
    if (name.isNotEmpty && name != _storedLecturerName) {
      SignatureService.saveLecturerName(name);
      if (mounted) setState(() => _storedLecturerName = name);
    }
  }

  Future<void> _clearSavedLecturerName() async {
    await SignatureService.clearLecturerName();
    _lecturerNameController.clear();
    if (mounted) setState(() => _storedLecturerName = null);
  }

  // ── Catalogue helpers ─────────────────────────────────────────────────────────

  Future<void> _loadCatalogue() async {
    final semesters = await CourseService.loadSemesters();
    final courses   = await CourseService.loadCourses();
    if (!mounted) return;
    final active = semesters.firstWhere((s) => s.isActive, orElse: () => semesters.first);
    _semesterPickerController.text = semesters.isNotEmpty ? active.label : '';
    _coursePickerController.clear();
    setState(() {
      _semesters = semesters; _allCourses = courses;
      _selectedSemester = semesters.isNotEmpty ? active : null; _selectedCourse = null;
    });
  }

  List<CatalogueCourse> get _semesterCourses => _selectedSemester == null
      ? []
      : _allCourses.where((c) => c.semesterId == _selectedSemester!.id).toList();

  void _onSemesterChanged(Semester sem) {
    _semesterPickerController.text = sem.label;
    _coursePickerController.clear();
    _courseNameController.clear();
    _courseCodeController.clear();
    setState(() { _selectedSemester = sem; _selectedCourse = null; });
  }

  void _onCourseSelected(CatalogueCourse course) {
    _coursePickerController.text = course.name;
    _courseNameController.text   = course.name;
    _courseCodeController.text   = course.code;
    setState(() => _selectedCourse = course);
  }

  // ── Pickers ───────────────────────────────────────────────────────────────────

  Future<void> _pickSemester() async {
    if (_semesters.isEmpty) return;
    final result = await showDialog<Semester>(
      context: context,
      builder: (_) => SemesterPickerDialog(semesters: _semesters, selectedId: _selectedSemester?.id),
    );
    if (result != null && mounted) _onSemesterChanged(result);
  }

  Future<void> _pickCourse() async {
    final courses = _semesterCourses;
    if (courses.isEmpty) return;
    final result = await showDialog<CatalogueCourse>(
      context: context,
      builder: (_) => CoursePickerDialog(courses: courses, selectedId: _selectedCourse?.id),
    );
    if (result != null && mounted) _onCourseSelected(result);
  }

  // ── Actions ───────────────────────────────────────────────────────────────────

  Future<void> _uploadPreviousSession() async {
    final sn      = context.read<SessionStateNotifier>();
    final success = await sn.uploadPreviousSession();
    if (!mounted) return;
    setState(() => _hasUploadedPrevious = success);
    final msg = success
        ? 'Previous session data loaded successfully'
        : (sn.error ?? 'Failed to load previous session');
    success ? context.showSuccess(msg) : context.showError(msg);
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;
    final duration    = int.tryParse(_durationController.text) ?? 0;
    final gracePeriod = int.tryParse(_gracePeriodController.text) ?? 0;
    if (gracePeriod >= duration) {
      context.showInfo('Grace period must be shorter than session duration.');
      return;
    }
    final name = _lecturerNameController.text.trim();
    final sn   = context.read<SessionStateNotifier>();

    if (name.isNotEmpty) await SignatureService.saveLecturerName(name);
    await sn.createSession(
      courseName:               _courseNameController.text,
      courseCode:               _courseCodeController.text.isNotEmpty ? _courseCodeController.text : null,
      lecturerName:             name,
      gracePeriodMinutes:       int.parse(_gracePeriodController.text),
      requiredConnectionMinutes: int.parse(_connectionTimeController.text),
      maxAttendanceCount:       int.parse(_maxAttendanceController.text),
      durationMinutes:          int.parse(_durationController.text),
    );
    if (!mounted) return;
    if (sn.error == null) {
      context.navigateTo(RouteConstants.dashboard);
    } else {
      context.showError(sn.error!);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<SessionStateNotifier>().isLoading;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.navigateTo(RouteConstants.home)),
        title:   const Text('Setup New Session'),
        actions: [
          TextButton.icon(
            onPressed: () => context.pushRoute(RouteConstants.catalogue),
            icon:  const Icon(Icons.menu_book_outlined, size: 18),
            label: const Text('Catalogue'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._headerSection(),
                  const SizedBox(height: AppSpacing.xl),
                  UploadPreviousCard(isUploaded: _hasUploadedPrevious, onUpload: _uploadPreviousSession),
                  const SizedBox(height: AppSpacing.lg),
                  LecturerNameField(controller: _lecturerNameController, focusNode: _lecturerNameFocus, storedName: _storedLecturerName, onClearSaved: _clearSavedLecturerName),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCourseSection(),
                  const SizedBox(height: AppSpacing.md),
                  _courseNameField(),
                  const SizedBox(height: AppSpacing.md),
                  _courseCodeField(),
                  const SizedBox(height: AppSpacing.md),
                  TimingFieldsSection(durationController: _durationController, gracePeriodController: _gracePeriodController, connectionTimeController: _connectionTimeController, maxAttendanceController: _maxAttendanceController),
                  const SizedBox(height: AppSpacing.xxl),
                  StartSessionButton(onPressed: _createSession, isLoading: isLoading),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Private builders ──────────────────────────────────────────────────────────

  List<Widget> _headerSection() => [
    Text('Configure Attendance Session', style: context.textStyles.headlineMedium?.bold),
    const SizedBox(height: AppSpacing.md),
    Text(
      'Set up the parameters for your attendance session and '
      'optionally upload previous session data for cumulative tracking.',
      style: context.textStyles.bodyMedium?.withColor(Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  ];

  Widget _buildCourseSection() => _semesters.isEmpty
      ? NoCatalogueNotice(onGoToCatalogue: () => context.pushRoute(RouteConstants.catalogue))
      : CoursePicker(
          semesterController: _semesterPickerController,
          courseController:   _coursePickerController,
          selectedSemester:   _selectedSemester,
          selectedCourse:     _selectedCourse,
          hasCourses:         _semesterCourses.isNotEmpty,
          onSemesterTap:      _pickSemester,
          onCourseTap:        _pickCourse,
        );

  Widget _courseNameField() => TextFormField(
    controller: _courseNameController,
    decoration: const InputDecoration(labelText: 'Course Name', hintText: 'e.g. Computer Science 101', border: OutlineInputBorder(), prefixIcon: Icon(Icons.book_outlined)),
    validator:  (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
  );

  Widget _courseCodeField() => TextFormField(
    controller: _courseCodeController,
    decoration: const InputDecoration(labelText: 'Course Code', hintText: 'e.g. CS101', border: OutlineInputBorder(), prefixIcon: Icon(Icons.code)),
    validator:  (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
  );
}
