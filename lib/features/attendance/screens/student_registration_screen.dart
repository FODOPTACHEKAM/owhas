import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../models/session.dart';
import '../../../services/api_service.dart';
import '../../session/notifiers/session_state_notifier.dart';
import '../notifiers/attendance_record_notifier.dart';
import '../../../services/face_recognition_service.dart';
import '../../../theme.dart';
import '../../../pages/face_capture_page.dart';
import '../widgets/registration_card.dart';
import '../widgets/registration_steps.dart';
import '../widgets/registration_widgets.dart';
import '../widgets/success_dialog.dart';

/// Refactored student self-registration — build() ≤ 60 lines.
///
/// The existing [StudentRegistrationPage] in `lib/pages/` is untouched
/// until routing is migrated in a later phase.
class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen>
    with SingleTickerProviderStateMixin {
  int              _currentStep     = 0;
  bool             _isLoading       = false;
  String           _statusMessage   = 'Enter the 4-digit PIN from your instructor.';
  String?          _errorMessage;
  PinVerifyState   _pinVerifyState  = PinVerifyState.idle;

  final _pinFormKey      = GlobalKey<FormState>();
  final _detailsFormKey  = GlobalKey<FormState>();
  final _pinController   = TextEditingController();
  final _matriculeCtrl   = TextEditingController();
  final _nameCtrl        = TextEditingController();
  final _emailCtrl       = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim  = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOut)));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
        CurvedAnimation(parent: _animCtrl, curve: const Interval(0.2, 1, curve: Curves.easeOut)));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    for (final c in [_pinController, _matriculeCtrl, _nameCtrl, _emailCtrl]) { c.dispose(); }
    super.dispose();
  }

  // ── Navigation helpers ────────────────────────────────────────────────────────

  void _goToPinStep() => setState(() {
    _currentStep = 0; _errorMessage = null;
    _statusMessage = 'Enter the 4-digit PIN from your instructor.';
  });

  void _goToDetailsStep() => setState(() {
    _currentStep = 1; _errorMessage = null;
    _statusMessage = 'Review your details before continuing.';
  });

  // ── Step logic ────────────────────────────────────────────────────────────────

  Future<void> _verifyPin() async {
    if (!_pinFormKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; _pinVerifyState = PinVerifyState.verifying; _statusMessage = 'Verifying PIN with server…'; });

    final pin      = _pinController.text.trim();
    final verified = await ApiService().verifySessionPin(pin);
    if (!mounted) return;

    bool isValid = verified;
    if (!verified) {
      final local = context.read<SessionStateNotifier>().activeSession?.sessionPin;
      if (local != null && local == pin) isValid = true;
    }

    if (isValid) {
      setState(() { _isLoading = false; _pinVerifyState = PinVerifyState.success; _errorMessage = null; _statusMessage = 'PIN verified. Fill in your student details.'; });
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() { _currentStep = 1; _pinVerifyState = PinVerifyState.idle; });
    } else {
      setState(() {
        _isLoading = false; _pinVerifyState = PinVerifyState.error;
        _errorMessage = 'Invalid PIN or server unreachable. Check your PIN and ensure you are on the class network.';
        _statusMessage = 'Enter the 4-digit PIN from your instructor.';
      });
    }
  }

  void _submitDetails() {
    if (!_detailsFormKey.currentState!.validate()) return;
    setState(() { _currentStep = 2; _errorMessage = null; _statusMessage = 'Position your face inside the oval guide, then tap Capture.'; });
  }

  Future<void> _captureAndRegister() async {
    final result = await Navigator.push<FaceCaptureResult>(
        context, MaterialPageRoute(builder: (_) => const FaceCapturePage()));
    if (result == null || !mounted) return;
    setState(() { _isLoading = true; _statusMessage = 'Checking face uniqueness…'; });

    final session = context.read<SessionStateNotifier>().activeSession;

    if (session == null) {
      await _registerDirect(pin: _pinController.text.trim(),
          matricule: _matriculeCtrl.text.trim(), name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim());
    } else {
      await _registerViaSession(
          rn: context.read<AttendanceRecordNotifier>(), session: session, faceResult: result,
          matricule: _matriculeCtrl.text.trim(), name: _nameCtrl.text.trim(), email: _emailCtrl.text.trim());
    }
  }

  Future<void> _registerDirect({required String pin, required String matricule, required String name, required String email}) async {
    try {
      final api = ApiService()..setSessionPin(pin);
      await api.registerStudentOnServer(username: name, matricule: matricule, email: email);
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: Failed to register student on server: ', '').replaceFirst('Exception: ', '');
        _statusMessage = 'Tap Capture to try again.';
      });
    }
  }

  Future<void> _registerViaSession({
    required AttendanceRecordNotifier rn,
    required AttendanceSession session,
    required FaceCaptureResult faceResult,
    required String matricule,
    required String name,
    required String email,
  }) async {
    final faceService = FaceRecognitionService();
    final dupName = faceService.findDuplicate(session.id, faceResult.descriptor);
    if (dupName != null) {
      setState(() { _isLoading = false; _errorMessage = 'This face is already registered under "$dupName". Proxy attendance is not allowed.'; _statusMessage = 'Tap Capture to try again.'; });
      return;
    }
    final success = await rn.registerStudent(
        session: session, matricule: matricule, studentName: name, email: email.isNotEmpty ? email : null);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      faceService.storeFace(session.id, matricule, name, faceResult.descriptor);
      _showSuccessDialog();
    } else {
      setState(() { _currentStep = 1; _errorMessage = rn.error ?? 'Registration failed. Try again.'; _statusMessage = 'Correct your details and continue.'; });
    }
  }

  void _showSuccessDialog() {
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => SuccessDialog(onDismissed: _resetForm));
  }

  void _resetForm() => setState(() {
    _currentStep = 0; _errorMessage = null; _pinVerifyState = PinVerifyState.idle;
    _statusMessage = 'Enter the 4-digit PIN from your instructor.';
    for (final c in [_pinController, _matriculeCtrl, _nameCtrl, _emailCtrl]) { c.clear(); }
  });

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.tertiary],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackButton(context),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: SingleChildScrollView(
                      padding: AppSpacing.paddingLg,
                      child: Center(
                        child: RegistrationCard(
                          currentStep:   _currentStep,
                          statusMessage: _statusMessage,
                          child:         _buildStepContent(),
                        ),
                      ),
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

  // ── Private builders ──────────────────────────────────────────────────────────

  Widget _buildStepContent() => switch (_currentStep) {
    0 => PinStep(formKey: _pinFormKey, controller: _pinController, pinVerifyState: _pinVerifyState, errorMessage: _errorMessage, isLoading: _isLoading, onVerify: _verifyPin),
    1 => DetailsStep(formKey: _detailsFormKey, matriculeController: _matriculeCtrl, nameController: _nameCtrl, emailController: _emailCtrl, errorMessage: _errorMessage, onBack: _goToPinStep, onContinue: _submitDetails),
    _ => FaceStep(errorMessage: _errorMessage, isLoading: _isLoading, onBack: _isLoading ? null : _goToDetailsStep, onCapture: _isLoading ? null : _captureAndRegister),
  };

  Widget _buildBackButton(BuildContext context) => Padding(
    padding: AppSpacing.paddingMd,
    child: GestureDetector(
      onTap: () => context.navigateTo(RouteConstants.home),
      child: Container(
        padding:    const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:        Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
      ),
    ),
  );
}
