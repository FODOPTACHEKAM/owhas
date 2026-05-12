import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../services/course_service.dart';
import '../services/signature_service.dart';
import '../theme.dart';

/// Page for setting up a new attendance session
class SessionSetupPage extends StatefulWidget {
  const SessionSetupPage({super.key});

  @override
  State<SessionSetupPage> createState() => _SessionSetupPageState();
}

class _SessionSetupPageState extends State<SessionSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _lecturerNameController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _courseCodeController = TextEditingController();
  final _gracePeriodController = TextEditingController(text: '5');
  final _connectionTimeController = TextEditingController(text: '10');
  final _maxAttendanceController = TextEditingController(text: '200');
  final _durationController = TextEditingController(text: '60');

  final List<Map<String, String>> _savedCourses = [];
  bool _hasUploadedPrevious = false;
  bool _hasSavedLecturerName = false;
  String? _selectedCourseCode;
  
  @override
  void initState() {
    super.initState();
    _lecturerNameController.addListener(_onLecturerNameChanged);
    _loadSavedLecturerName();
    _loadSavedCourses();
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
          setState(() {
            _hasSavedLecturerName = true;
          });
        }
      });
    }
  }

  Future<void> _loadSavedCourses() async {
    final courses = await CourseService.loadCourses();
    if (mounted) {
      setState(() {
        _savedCourses
          ..clear()
          ..addAll(courses);
      });
    }
  }

  void _selectSavedCourse(String? selectedCode) {
    if (selectedCode == null) return;
    final selected = _savedCourses.firstWhere(
      (course) => course['code'] == selectedCode,
      orElse: () => <String, String>{},
    );

    if (selected.isNotEmpty && mounted) {
      setState(() {
        _selectedCourseCode = selectedCode;
        _courseNameController.text = selected['name'] ?? '';
        _courseCodeController.text = selected['code'] ?? '';
      });
    }
  }

  Future<void> _showAddCourseDialog() async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add saved course'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Course Name',
                    hintText: 'e.g., Computer Science 101',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code',
                    hintText: 'e.g., CS101',
                  ),
                  validator: (value) =>
                      value?.trim().isEmpty ?? true ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final courseName = nameController.text.trim();
      final courseCode = codeController.text.trim().toUpperCase();
      await CourseService.saveCourse(
        courseName: courseName,
        courseCode: courseCode,
      );
      await _loadSavedCourses();
      if (mounted) {
        setState(() {
          _courseNameController.text = courseName;
          _courseCodeController.text = courseCode;
          _selectedCourseCode = courseCode;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course saved for future sessions')),
        );
      }
    }
  }

  @override
  void dispose() {
    _lecturerNameController.removeListener(_onLecturerNameChanged);
    _lecturerNameController.dispose();
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
      setState(() {
        _hasUploadedPrevious = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Previous session data loaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to load previous session'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _createSession() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AttendanceProvider>();
    final lecturerName = _lecturerNameController.text.trim();

    // Persist lecturer name for future sessions
    if (lecturerName.isNotEmpty) {
      await SignatureService.saveLecturerName(lecturerName);
    }

    await provider.createSession(
      courseName: _courseNameController.text,
      courseCode: _courseCodeController.text.isNotEmpty ? _courseCodeController.text : null,
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
              // Header
              Text(
                'Configure Attendance Session',
                style: context.textStyles.headlineMedium?.bold,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Set up the parameters for your attendance session and optionally upload previous session data for cumulative tracking.',
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
                            _hasUploadedPrevious ? Icons.check_circle : Icons.upload_file,
                            color: _hasUploadedPrevious
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
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
                        'Load previous attendance data to maintain cumulative totals. The system supports Excel (.xlsx, .xls) and PDF (.pdf) files, and will automatically map existing student records.',
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
                  hintText: 'e.g., Dr. Stephane Pride',
                  helperText: 'Saved automatically for future sessions',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                    value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

              // Course Name
              TextFormField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: 'Course Name',
                  hintText: 'e.g., Computer Science 101',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.book),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.sm),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 520;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedCourseCode,
                              decoration: const InputDecoration(
                                labelText: 'Select Saved Course',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Choose saved course'),
                              items: _savedCourses.map((course) {
                                return DropdownMenuItem<String>(
                                  value: course['code'],
                                  child: Text('${course['name']} (${course['code']})'),
                                );
                              }).toList(),
                              onChanged: _savedCourses.isEmpty ? null : _selectSavedCourse,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: _showAddCourseDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedCourseCode,
                                decoration: const InputDecoration(
                                  labelText: 'Select Saved Course',
                                  border: OutlineInputBorder(),
                                ),
                                hint: const Text('Choose saved course'),
                                items: _savedCourses.map((course) {
                                  return DropdownMenuItem<String>(
                                    value: course['code'],
                                    child: Text('${course['name']} (${course['code']})'),
                                  );
                                }).toList(),
                                onChanged: _savedCourses.isEmpty ? null : _selectSavedCourse,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: _showAddCourseDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Add'),
                            ),
                          ],
                        );
                },
              ),
              if (_savedCourses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Add courses here so you can quickly pick the course and auto-fill its code.',
                    style: context.textStyles.bodySmall?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),

              // Course Code
              TextFormField(
                controller: _courseCodeController,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g., CS101',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),

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
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (int.tryParse(value!) == null) return 'Must be a number';
                            if (int.parse(value) <= 0) return 'Must be greater than 0';
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
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (int.tryParse(value!) == null) return 'Must be a number';
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
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (int.tryParse(value!) == null) return 'Must be a number';
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
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Required';
                            if (int.tryParse(value!) == null) return 'Must be a number';
                            return null;
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Create Session Button
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
}



