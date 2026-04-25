import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../theme.dart';

/// Page for setting up a new attendance session
class SessionSetupPage extends StatefulWidget {
  const SessionSetupPage({super.key});

  @override
  State<SessionSetupPage> createState() => _SessionSetupPageState();
}

class _SessionSetupPageState extends State<SessionSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _courseNameController = TextEditingController();
  final _gracePeriodController = TextEditingController(text: '5');
  final _connectionTimeController = TextEditingController(text: '15');
  final _maxAttendanceController = TextEditingController(text: '30');

  bool _hasUploadedPrevious = false;

  @override
  void dispose() {
    _courseNameController.dispose();
    _gracePeriodController.dispose();
    _connectionTimeController.dispose();
    _maxAttendanceController.dispose();
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
    
    await provider.createSession(
      courseName: _courseNameController.text,
      gracePeriodMinutes: int.parse(_gracePeriodController.text),
      requiredConnectionMinutes: int.parse(_connectionTimeController.text),
      maxAttendanceCount: int.parse(_maxAttendanceController.text),
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
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('Setup New Session'),
      ),
      body: SingleChildScrollView(
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
                        'Load previous attendance data to maintain cumulative totals. The system will automatically map existing student records.',
                        style: context.textStyles.bodySmall?.withColor(
                          Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.tonal(
                        onPressed: _uploadPreviousSession,
                        child: const Text('Choose Excel File'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

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
              const SizedBox(height: AppSpacing.md),

              // Grace Period
              TextFormField(
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
              const SizedBox(height: AppSpacing.md),

              // Required Connection Time
              TextFormField(
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
              const SizedBox(height: AppSpacing.md),

              // Max Attendance Count
              TextFormField(
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
    );
  }
}
