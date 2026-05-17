import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Step labels and icons used by [StepHeader].
const stepTitles    = ['Enter Session PIN', 'Personal Details', 'Face Verification'];
const stepSubtitles = ['Secure access verification', 'Student information', 'Identity confirmation'];
const stepIcons     = [Icons.lock_outline, Icons.person_outline, Icons.face_retouching_natural];

/// Frosted-glass card scaffold that wraps all three registration steps.
class RegistrationCard extends StatelessWidget {
  const RegistrationCard({
    super.key,
    required this.currentStep,
    required this.statusMessage,
    required this.child,
  });

  final int     currentStep;
  final String  statusMessage;
  final Widget  child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border:       Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            mainAxisSize:        MainAxisSize.min,
            crossAxisAlignment:  CrossAxisAlignment.stretch,
            children: [
              const _CardHeader(),
              Padding(
                padding: AppSpacing.paddingXl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StepIndicators(currentStep: currentStep),
                    const SizedBox(height: AppSpacing.xl),
                    StepHeader(currentStep: currentStep),
                    const SizedBox(height: AppSpacing.xl),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child:   SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
                          child:    child,
                        ),
                      ),
                      child: KeyedSubtree(key: ValueKey(currentStep), child: child),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    StatusBar(message: statusMessage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Text('Attendance Registration',
              style: context.textStyles.titleLarge?.bold.withColor(Colors.white),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Secure access verification and student registration',
              style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.8)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Animated pill progress dots showing which step is active.
class StepIndicators extends StatelessWidget {
  const StepIndicators({super.key, required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == currentStep;
        final isDone   = i < currentStep;
        return AnimatedContainer(
          duration:   const Duration(milliseconds: 300),
          curve:      Curves.easeInOut,
          margin:     const EdgeInsets.symmetric(horizontal: 4),
          width:      isActive ? 28 : 10,
          height:     10,
          decoration: BoxDecoration(
            color:        (isActive || isDone) ? Colors.white : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }
}

/// Row with step icon, title, subtitle, and step counter badge.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.currentStep});
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:    const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(stepIcons[currentStep], color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stepTitles[currentStep],
                  style: context.textStyles.titleMedium?.bold.withColor(Colors.white)),
              Text(stepSubtitles[currentStep],
                  style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
        Container(
          padding:    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: Text('${currentStep + 1} / 3',
              style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.8))),
        ),
      ],
    );
  }
}

/// Left-accented status bar at the bottom of the card.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color:        Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border:       Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.7), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATUS', style: context.textStyles.bodySmall?.bold.withColor(Colors.white)),
          const SizedBox(height: 4),
          Text(message, style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}
