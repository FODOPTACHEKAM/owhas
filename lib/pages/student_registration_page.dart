import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../services/api_service.dart';
import '../services/face_recognition_service.dart';
import '../theme.dart';
import 'face_capture_page.dart';

// ---------------------------------------------------------------------------
// PIN verification state
// ---------------------------------------------------------------------------

enum _PinVerifyState { idle, verifying, success, error }

// ---------------------------------------------------------------------------
// Step metadata
// ---------------------------------------------------------------------------

const _stepTitles = ['Enter Session PIN', 'Personal Details', 'Face Verification'];
const _stepSubtitles = [
  'Secure access verification',
  'Student information',
  'Identity confirmation',
];
const _stepIcons = [
  Icons.lock_outline,
  Icons.person_outline,
  Icons.face_retouching_natural,
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class StudentRegistrationPage extends StatefulWidget {
  const StudentRegistrationPage({super.key});

  @override
  State<StudentRegistrationPage> createState() =>
      _StudentRegistrationPageState();
}

class _StudentRegistrationPageState extends State<StudentRegistrationPage>
    with SingleTickerProviderStateMixin {
  // ---- Step state ----
  int _currentStep = 0;

  // ---- Step 0: PIN ----
  final _pinFormKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  _PinVerifyState _pinVerifyState = _PinVerifyState.idle;

  // ---- Step 1: Details ----
  final _detailsFormKey = GlobalKey<FormState>();
  final _matriculeController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // ---- Shared UI state ----
  bool _isLoading = false;
  String _statusMessage = 'Enter the 4-digit PIN from your instructor.';
  String? _errorMessage;

  // ---- Entrance animation ----
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.2, 1, curve: Curves.easeOut),
      ),
    );
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _pinController.dispose();
    _matriculeController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step logic
  // ---------------------------------------------------------------------------

  Future<void> _verifyPin() async {
    if (!_pinFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pinVerifyState = _PinVerifyState.verifying;
      _statusMessage = 'Verifying PIN with server…';
    });

    final pin = _pinController.text.trim();
    final verified = await ApiService().verifySessionPin(pin);

    if (!mounted) return;

    bool isValid = verified;
    if (!verified) {
      final localPin =
          context.read<AttendanceProvider>().activeSession?.sessionPin;
      if (localPin != null && localPin == pin) isValid = true;
    }

    if (isValid) {
      setState(() {
        _isLoading = false;
        _pinVerifyState = _PinVerifyState.success;
        _errorMessage = null;
        _statusMessage = 'PIN verified. Fill in your student details.';
      });
      // Brief success flash before advancing
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _currentStep = 1;
        _pinVerifyState = _PinVerifyState.idle;
      });
    } else {
      setState(() {
        _isLoading = false;
        _pinVerifyState = _PinVerifyState.error;
        _errorMessage =
            'Invalid PIN or server unreachable. Check your PIN and ensure you are on the class network.';
        _statusMessage = 'Enter the 4-digit PIN from your instructor.';
      });
    }
  }

  void _submitDetails() {
    if (!_detailsFormKey.currentState!.validate()) return;
    setState(() {
      _currentStep = 2;
      _errorMessage = null;
      _statusMessage =
          'Position your face inside the oval guide, then tap Capture.';
    });
  }

  Future<void> _captureAndRegister() async {
    final faceResult = await Navigator.push<FaceCaptureResult>(
      context,
      MaterialPageRoute(builder: (_) => const FaceCapturePage()),
    );

    if (faceResult == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking face uniqueness…';
    });

    final provider = context.read<AttendanceProvider>();
    final sessionId = provider.activeSession?.id;
    final pin = _pinController.text.trim();
    final matricule = _matriculeController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    // ── Student's own device: no local session, register directly on server ──
    if (sessionId == null) {
      try {
        final api = ApiService();
        api.setSessionPin(pin);
        await api.registerStudentOnServer(
          username: name,
          matricule: matricule,
          email: email,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSuccessDialog();
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString()
              .replaceFirst('Exception: Failed to register student on server: ', '')
              .replaceFirst('Exception: ', '');
          _statusMessage = 'Tap Capture to try again.';
        });
      }
      return;
    }

    // ── Lecturer's device: has active local session ──
    final faceService = FaceRecognitionService();
    final dupName = faceService.findDuplicate(sessionId, faceResult.descriptor);
    if (dupName != null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'This face is already registered under "$dupName". Proxy attendance is not allowed.';
        _statusMessage = 'Tap Capture to try again.';
      });
      return;
    }

    final success = await provider.registerStudent(
      matricule: matricule,
      studentName: name,
      email: email.isNotEmpty ? email : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      faceService.storeFace(sessionId, matricule, name, faceResult.descriptor);
      _showSuccessDialog();
    } else {
      setState(() {
        _currentStep = 1;
        _errorMessage = provider.error ?? 'Registration failed. Try again.';
        _statusMessage = 'Correct your details and continue.';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Dialogs / reset
  // ---------------------------------------------------------------------------

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(onDismissed: _resetForm),
    );
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _pinController.clear();
      _matriculeController.clear();
      _nameController.clear();
      _emailController.clear();
      _errorMessage = null;
      _pinVerifyState = _PinVerifyState.idle;
      _statusMessage = 'Enter the 4-digit PIN from your instructor.';
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Padding(
                padding: AppSpacing.paddingMd,
                child: GestureDetector(
                  onTap: () => context.go('/'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),

              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: AppSpacing.paddingLg,
                      child: Center(child: _buildCard()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card scaffold
  // ---------------------------------------------------------------------------

  Widget _buildCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCardHeader(),
              Padding(
                padding: AppSpacing.paddingXl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepIndicators(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildStepHeader(),
                    const SizedBox(height: AppSpacing.xl),
                    // Animated step content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.08, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey(_currentStep),
                        child: _buildStepContent(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _buildStatusBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card header
  // ---------------------------------------------------------------------------

  Widget _buildCardHeader() {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Text(
            'Attendance Registration',
            style:
                context.textStyles.titleLarge?.bold.withColor(Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Secure access verification and student registration',
            style: context.textStyles.bodySmall
                ?.withColor(Colors.white.withValues(alpha: 0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step indicators (pills)
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: (isActive || isDone)
                ? Colors.white
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(5),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Step header (icon + title + counter)
  // ---------------------------------------------------------------------------

  Widget _buildStepHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Icon(_stepIcons[_currentStep], color: Colors.white, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stepTitles[_currentStep],
                style: context.textStyles.titleMedium?.bold
                    .withColor(Colors.white),
              ),
              Text(
                _stepSubtitles[_currentStep],
                style: context.textStyles.bodySmall
                    ?.withColor(Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentStep + 1} / 3',
            style: context.textStyles.bodySmall
                ?.withColor(Colors.white.withValues(alpha: 0.8)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step content dispatcher
  // ---------------------------------------------------------------------------

  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => _buildPinStep(),
      1 => _buildDetailsStep(),
      _ => _buildFaceStep(),
    };
  }

  // ---- Step 0: PIN ----

  Widget _buildPinStep() {
    return Form(
      key: _pinFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlassTextField(
            controller: _pinController,
            label: 'Session PIN',
            icon: Icons.dialpad,
            keyboardType: TextInputType.number,
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
          _PinStatusBadge(state: _pinVerifyState, error: _errorMessage),
          const SizedBox(height: AppSpacing.md),
          _ActionButton(
            label: 'Verify PIN',
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _verifyPin,
          ),
        ],
      ),
    );
  }

  // ---- Step 1: Details ----

  Widget _buildDetailsStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GlassTextField(
            controller: _matriculeController,
            label: 'Matricule',
            icon: Icons.badge,
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _GlassTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _GlassTextField(
            controller: _emailController,
            label: 'Email Address',
            icon: Icons.alternate_email,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          if (_errorMessage != null) _buildErrorText(_errorMessage!),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _BackButton(
                onPressed: () => setState(() {
                  _currentStep = 0;
                  _errorMessage = null;
                  _statusMessage =
                      'Enter the 4-digit PIN from your instructor.';
                }),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: _ActionButton(
                  label: 'Continue',
                  onPressed: _submitDetails,
                  isLoading: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Step 2: Face ----

  Widget _buildFaceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Face guide illustration
        Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 90,
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7), width: 2),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 40,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Look directly at the camera',
                style: context.textStyles.bodySmall
                    ?.withColor(Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) _buildErrorText(_errorMessage!),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            _BackButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _currentStep = 1;
                        _errorMessage = null;
                        _statusMessage =
                            'Review your details before continuing.';
                      }),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: _ActionButton(
                label: _errorMessage != null ? 'Retry Capture' : 'Open Camera',
                icon: Icons.camera_alt,
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _captureAndRegister,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar (bottom of card)
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(
          left: BorderSide(
              color: Colors.white.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STATUS',
            style: context.textStyles.bodySmall?.bold
                .withColor(Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            _statusMessage,
            style: context.textStyles.bodySmall
                ?.withColor(Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorText(String message) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        message,
        style: context.textStyles.bodySmall?.withColor(Colors.redAccent),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets
// ---------------------------------------------------------------------------

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        prefixIcon:
            Icon(icon, color: Colors.white.withValues(alpha: 0.8)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.primary,
        padding: AppSpacing.verticalMd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: context.textStyles.titleSmall?.semiBold,
                ),
              ],
            ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
        padding: AppSpacing.verticalMd,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(
        'Back',
        style: context.textStyles.titleSmall?.withColor(Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN status badge
// ---------------------------------------------------------------------------

class _PinStatusBadge extends StatelessWidget {
  final _PinVerifyState state;
  final String? error;

  const _PinStatusBadge({required this.state, this.error});

  @override
  Widget build(BuildContext context) {
    Widget? content;

    switch (state) {
      case _PinVerifyState.verifying:
        content = _badge(
          key: const ValueKey('verifying'),
          color: Colors.white.withValues(alpha: 0.15),
          border: Colors.white.withValues(alpha: 0.3),
          icon: const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          label: 'Verifying PIN with server…',
          labelColor: Colors.white.withValues(alpha: 0.9),
        );
      case _PinVerifyState.success:
        content = _badge(
          key: const ValueKey('success'),
          color: Colors.green.withValues(alpha: 0.25),
          border: Colors.greenAccent.withValues(alpha: 0.6),
          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.greenAccent),
          label: 'PIN Verified!',
          labelColor: Colors.greenAccent,
        );
      case _PinVerifyState.error:
        content = _badge(
          key: const ValueKey('error'),
          color: Colors.red.withValues(alpha: 0.18),
          border: Colors.redAccent.withValues(alpha: 0.5),
          icon: const Icon(Icons.cancel_rounded, size: 16, color: Colors.redAccent),
          label: error ?? 'Invalid PIN.',
          labelColor: Colors.redAccent,
        );
      case _PinVerifyState.idle:
        content = const SizedBox.shrink(key: ValueKey('idle'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.3),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: content,
    );
  }

  Widget _badge({
    required Key key,
    required Color color,
    required Color border,
    required Widget icon,
    required String label,
    required Color labelColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Success dialog
// ---------------------------------------------------------------------------

class _SuccessDialog extends StatefulWidget {
  final VoidCallback? onDismissed;
  const _SuccessDialog({this.onDismissed});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          padding: AppSpacing.paddingXl,
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 80),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Registered Successfully!',
                style:
                    context.textStyles.titleLarge?.bold.withColor(Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Stay connected for verification',
                style: context.textStyles.bodyMedium
                    ?.withColor(Colors.white.withValues(alpha: 0.9)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
