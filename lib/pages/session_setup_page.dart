import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/semester.dart';
import '../models/catalogue_course.dart';
import '../providers/attendance_provider.dart';
import '../services/course_service.dart';
import '../services/signature_service.dart';
import '../theme.dart';

class SessionSetupPage extends StatefulWidget {
  const SessionSetupPage({super.key});

  @override
  State<SessionSetupPage> createState() => _SessionSetupPageState();
}

class _SessionSetupPageState extends State<SessionSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _lecturerNameController = TextEditingController();
  // Display-only controllers for the picker fields (readOnly)
  final _semesterPickerController = TextEditingController();
  final _coursePickerController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _gracePeriodController = TextEditingController(text: '5');
  final _connectionTimeController = TextEditingController(text: '10');
  final _maxAttendanceController = TextEditingController(text: '200');
  final _durationController = TextEditingController(text: '60');

  List<Semester> _semesters = [];
  List<CatalogueCourse> _allCourses = [];
  Semester? _selectedSemester;
  CatalogueCourse? _selectedCourse;

  bool _hasUploadedPrevious = false;
  bool _hasSavedLecturerName = false;

  @override
  void initState() {
    super.initState();
    _lecturerNameController.addListener(_onLecturerNameChanged);
    _loadSavedLecturerName();
    _loadCatalogue();
  }

  Future<void> _loadSavedLecturerName() async {
    final savedName = await SignatureService.loadLecturerName();
    if (savedName != null && savedName.isNotEmpty && mounted) {
      setState(() {
        _lecturerNameController.text = savedName;
        _hasSavedLecturerName = true;
      });
    }
  }

  void _onLecturerNameChanged() {
    final name = _lecturerNameController.text.trim();
    if (!_hasSavedLecturerName && name.isNotEmpty) {
      SignatureService.saveLecturerName(name).then((saved) {
        if (saved && mounted) {
          setState(() => _hasSavedLecturerName = true);
        }
      });
    }
  }

  Future<void> _loadCatalogue() async {
    final semesters = await CourseService.loadSemesters();
    final courses = await CourseService.loadCourses();
    if (!mounted) return;

    Semester? activeSem;
    for (final s in semesters) {
      if (s.isActive) {
        activeSem = s;
        break;
      }
    }
    activeSem ??= semesters.isNotEmpty ? semesters.first : null;

    // Update display controllers outside setState to avoid double-notify
    _semesterPickerController.text = activeSem?.label ?? '';
    _coursePickerController.clear();

    setState(() {
      _semesters = semesters;
      _allCourses = courses;
      _selectedSemester = activeSem;
      _selectedCourse = null;
    });
  }

  List<CatalogueCourse> get _semesterCourses {
    if (_selectedSemester == null) return [];
    return _allCourses
        .where((c) => c.semesterId == _selectedSemester!.id)
        .toList();
  }

  void _onSemesterChanged(Semester sem) {
    _semesterPickerController.text = sem.label;
    _coursePickerController.clear();
    _courseNameController.clear();
    _courseCodeController.clear();
    setState(() {
      _selectedSemester = sem;
      _selectedCourse = null;
    });
  }

  void _onCourseSelected(CatalogueCourse course) {
    _coursePickerController.text = course.name;
    _courseNameController.text = course.name;
    _courseCodeController.text = course.code;
    setState(() => _selectedCourse = course);
  }

  // ── Pickers (dialog-based — no overlay render-tree conflicts) ────────────────

  Future<void> _pickSemester() async {
    if (_semesters.isEmpty) return;
    final result = await showDialog<Semester>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SimpleDialog(
          title: const Text('Select Semester'),
          children: _semesters.map((s) {
            final isSelected = s.id == _selectedSemester?.id;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, s),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (s.isActive)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
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
      },
    );
    if (result != null && mounted) _onSemesterChanged(result);
  }

  Future<void> _pickCourse() async {
    final courses = _semesterCourses;
    if (courses.isEmpty) return;
    final result = await showDialog<CatalogueCourse>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SimpleDialog(
          title: const Text('Select Course'),
          children: courses.map((c) {
            final isSelected = c.id == _selectedCourse?.id;
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (c.department != null)
                          Text(
                            c.department!,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      c.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
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
      },
    );
    if (result != null && mounted) _onCourseSelected(result);
  }

  @override
  void dispose() {
    _lecturerNameController.removeListener(_onLecturerNameChanged);
    _lecturerNameController.dispose();
    _semesterPickerController.dispose();
    _coursePickerController.dispose();
    _courseNameController.dispose();
    _courseCodeController.dispose();
    _gracePeriodController.dispose();
    _connectionTimeController.dispose();
    _maxAttendanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _uploadPreviousSession() async {
    final provider = context.read<AttendanceProvider>();
    final success = await provider.uploadPreviousSession();

    if (mounted) {
      setState(() => _hasUploadedPrevious = success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Previous session data loaded successfully'
                : (provider.error ?? 'Failed to load previous session'),
          ),
          backgroundColor:
              success ? null : Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AttendanceProvider>();
    final lecturerName = _lecturerNameController.text.trim();

    if (lecturerName.isNotEmpty) {
      await SignatureService.saveLecturerName(lecturerName);
    }

    await provider.createSession(
      courseName: _courseNameController.text,
      courseCode: _courseCodeController.text.isNotEmpty
          ? _courseCodeController.text
          : null,
      lecturerName: lecturerName,
      gracePeriodMinutes: int.parse(_gracePeriodController.text),
      requiredConnectionMinutes: int.parse(_connectionTimeController.text),
      maxAttendanceCount: int.parse(_maxAttendanceController.text),
      durationMinutes: int.parse(_durationController.text),
    );

    if (mounted) {
      if (provider.error == null) {
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
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
          onPressed: () => context.go('/'),
        ),
        title: const Text('Setup New Session'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/catalogue'),
            icon: const Icon(Icons.menu_book_outlined, size: 18),
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
                  Text(
                    'Configure Attendance Session',
                    style: context.textStyles.headlineMedium?.bold,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Set up the parameters for your attendance session and '
                    'optionally upload previous session data for cumulative tracking.',
                    style: context.textStyles.bodyMedium?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Upload Previous Session Card
                  Card(
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _hasUploadedPrevious
                                    ? Icons.check_circle
                                    : Icons.upload_file,
                                color: _hasUploadedPrevious
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  'Upload Previous Session (Optional)',
                                  style:
                                      context.textStyles.titleMedium?.semiBold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Load previous attendance data to maintain cumulative '
                            'totals. Supports Excel (.xlsx, .xls) and PDF (.pdf) files.',
                            style: context.textStyles.bodySmall?.withColor(
                              Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton.tonal(
                            onPressed: _uploadPreviousSession,
                            child: const Text('Choose File (Excel or PDF)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Lecturer Name
                  TextFormField(
                    controller: _lecturerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Lecturer Name',
                      hintText: 'e.g. Dr. John Smith',
                      helperText: 'Saved automatically for future sessions',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Course Picker ─────────────────────────────────────────────
                  _buildCoursePicker(),
                  const SizedBox(height: AppSpacing.md),

                  // Course Name (editable override)
                  TextFormField(
                    controller: _courseNameController,
                    decoration: const InputDecoration(
                      labelText: 'Course Name',
                      hintText: 'e.g. Computer Science 101',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book_outlined),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Course Code (editable override)
                  TextFormField(
                    controller: _courseCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Course Code',
                      hintText: 'e.g. CS101',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.code),
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Timing fields
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = AppSpacing.md;
                      final fieldWidth = constraints.maxWidth < 680
                          ? double.infinity
                          : (constraints.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _durationController,
                              decoration: const InputDecoration(
                                labelText: 'Session Duration (minutes)',
                                hintText: 'How long the session stays open',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.hourglass_top),
                                suffixText: 'min',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return 'Required';
                                if (int.tryParse(v!) == null) {
                                  return 'Must be a number';
                                }
                                if (int.parse(v) <= 0) {
                                  return 'Must be greater than 0';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _gracePeriodController,
                              decoration: const InputDecoration(
                                labelText: 'Grace Period (minutes)',
                                hintText: 'Late arrival tolerance',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.timer),
                                suffixText: 'min',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return 'Required';
                                if (int.tryParse(v!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _connectionTimeController,
                              decoration: const InputDecoration(
                                labelText: 'Required Connection Time (minutes)',
                                hintText: 'Minimum time to stay connected',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.wifi),
                                suffixText: 'min',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return 'Required';
                                if (int.tryParse(v!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: TextFormField(
                              controller: _maxAttendanceController,
                              decoration: const InputDecoration(
                                labelText: 'Maximum Attendance Count',
                                hintText: 'Total number of sessions',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (v?.isEmpty ?? true) return 'Required';
                                if (int.tryParse(v!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Start Session Button
                  Consumer<AttendanceProvider>(
                    builder: (context, provider, _) {
                      return FilledButton(
                        onPressed: provider.isLoading ? null : _createSession,
                        child: Padding(
                          padding: AppSpacing.verticalMd,
                          child: provider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Start Session'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoursePicker() {
    final cs = Theme.of(context).colorScheme;

    if (_semesters.isEmpty) {
      return Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: cs.onSecondaryContainer, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'No courses configured. Visit the Course Catalogue to add your '
                "institution's courses for quick selection.",
                style: context.textStyles.bodySmall
                    ?.withColor(cs.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/catalogue'),
              child: const Text('Go'),
            ),
          ],
        ),
      );
    }

    final semCourses = _semesterCourses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Semester picker — readOnly field, tap opens SimpleDialog
        TextFormField(
          controller: _semesterPickerController,
          readOnly: true,
          onTap: _pickSemester,
          decoration: const InputDecoration(
            labelText: 'Semester',
            hintText: 'Tap to select semester',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_view_month_outlined),
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Course picker — readOnly field, tap opens SimpleDialog
        TextFormField(
          controller: _coursePickerController,
          readOnly: true,
          onTap: semCourses.isEmpty ? null : _pickCourse,
          decoration: InputDecoration(
            labelText: 'Select Course',
            hintText: semCourses.isEmpty ? null : 'Tap to select course',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.book_outlined),
            suffixIcon: semCourses.isEmpty
                ? null
                : const Icon(Icons.arrow_drop_down),
            helperText: _selectedSemester == null
                ? 'Pick a semester first'
                : semCourses.isEmpty
                    ? 'No courses in this semester — add some in the Catalogue'
                    : 'Name and code will be filled automatically',
          ),
        ),

        if (_selectedCourse != null && _selectedCourse!.department != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs, left: 12),
            child: Text(
              '${_selectedCourse!.department}'
              '${_selectedCourse!.credits != null ? '  ·  ${_selectedCourse!.credits} credits' : ''}',
              style: context.textStyles.bodySmall
                  ?.withColor(cs.onSurfaceVariant),
            ),
          ),

        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/catalogue'),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Manage Catalogue'),
          ),
        ),
      ],
    );
  }
}
