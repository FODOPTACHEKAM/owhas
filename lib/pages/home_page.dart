import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../theme.dart';

/// Home page - entry point for the application
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _handleLecturerTap(BuildContext context) {
    final provider = context.read<AttendanceProvider>();
    final hasActiveSession = provider.activeSession != null;

    if (!hasActiveSession) {
      context.go('/setup');
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lecturer Options'),
        content: const Text(
          'You already have an active session running. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/dashboard');
            },
            child: const Text('Go to Active Session'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/setup');
            },
            child: const Text('Create New Session'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingXl,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_tethering,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Title
                  Text(
                    'Hotspot Attendance',
                    style: context.textStyles.displaySmall?.bold,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Smart offline attendance tracking with security verification',
                    style: context.textStyles.bodyLarge?.withColor(
                      Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // Role Selection Cards
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        Consumer<AttendanceProvider>(
                          builder: (context, provider, _) {
                            final hasSession = provider.activeSession != null;
                            return _RoleCard(
                              title: 'Lecturer',
                              subtitle: hasSession
                                  ? 'Active session: ${provider.activeSession!.courseName}'
                                  : 'Create and manage attendance sessions',
                              icon: Icons.school,
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => _handleLecturerTap(context),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _RoleCard(
                          title: 'Student',
                          subtitle: 'Register attendance for active sessions',
                          icon: Icons.person,
                          color: Theme.of(context).colorScheme.secondary,
                          onTap: () => context.go('/register'),
                        ),
                      ],
                    ),
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

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleLarge?.semiBold,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: context.textStyles.bodyMedium?.withColor(
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


