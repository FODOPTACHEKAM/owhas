import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme.dart';
import 'registration_widgets.dart';

// ── Step 0: PIN entry ─────────────────────────────────────────────────────────

class PinStep extends StatelessWidget {
  const PinStep({
    super.key,
    required this.formKey,
    required this.controller,
    required this.pinVerifyState,
    required this.errorMessage,
    required this.isLoading,
    required this.onVerify,
  });

  final GlobalKey<FormState>  formKey;
  final TextEditingController controller;
  final PinVerifyState        pinVerifyState;
  final String?               errorMessage;
  final bool                  isLoading;
  final VoidCallback          onVerify;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(
            controller:      controller,
            label:           'Session PIN',
            icon:            Icons.dialpad,
            keyboardType:    TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length != 4) return 'PIN must be exactly 4 digits';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          PinStatusBadge(state: pinVerifyState, error: errorMessage),
          const SizedBox(height: AppSpacing.md),
          RegistrationActionButton(label: 'Verify PIN', isLoading: isLoading, onPressed: isLoading ? null : onVerify),
        ],
      ),
    );
  }
}

// ── Step 1: Personal details ──────────────────────────────────────────────────

class DetailsStep extends StatelessWidget {
  const DetailsStep({
    super.key,
    required this.formKey,
    required this.matriculeController,
    required this.nameController,
    required this.emailController,
    required this.errorMessage,
    required this.onBack,
    required this.onContinue,
  });

  final GlobalKey<FormState>  formKey;
  final TextEditingController matriculeController;
  final TextEditingController nameController;
  final TextEditingController emailController;
  final String?               errorMessage;
  final VoidCallback          onBack;
  final VoidCallback          onContinue;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassTextField(controller: matriculeController, label: 'Matricule',       icon: Icons.badge,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
          const SizedBox(height: AppSpacing.md),
          GlassTextField(controller: nameController,      label: 'Full Name',       icon: Icons.person_outline,
              validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null),
          const SizedBox(height: AppSpacing.md),
          GlassTextField(
            controller:   emailController,
            label:        'Email Address',
            icon:         Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
            validator:    (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) return 'Enter a valid email address';
              return null;
            },
          ),
          if (errorMessage != null) ErrorText(message: errorMessage!),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              RegistrationBackButton(onPressed: onBack),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 2,
                  child: RegistrationActionButton(label: 'Continue', isLoading: false, onPressed: onContinue)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Face capture ──────────────────────────────────────────────────────

class FaceStep extends StatelessWidget {
  const FaceStep({
    super.key,
    required this.errorMessage,
    required this.isLoading,
    required this.onBack,
    required this.onCapture,
  });

  final String?       errorMessage;
  final bool          isLoading;
  final VoidCallback? onBack;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height:     130,
          decoration: BoxDecoration(
            color:        Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:       Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72, height: 90,
                decoration: BoxDecoration(
                  border:       Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Icon(Icons.face_retouching_natural, color: Colors.white.withValues(alpha: 0.8), size: 40),
              ),
              const SizedBox(height: 8),
              Text('Look directly at the camera',
                  style: context.textStyles.bodySmall?.withColor(Colors.white.withValues(alpha: 0.7))),
            ],
          ),
        ),
        if (errorMessage != null) ErrorText(message: errorMessage!),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            RegistrationBackButton(onPressed: onBack),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 2,
                child: RegistrationActionButton(
                  label:     errorMessage != null ? 'Retry Capture' : 'Open Camera',
                  icon:      Icons.camera_alt,
                  isLoading: isLoading,
                  onPressed: onCapture,
                )),
          ],
        ),
      ],
    );
  }
}
