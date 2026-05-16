import 'package:flutter/material.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../services/cloud_service.dart';
import '../../../theme.dart';
import '../widgets/cloud_login_form.dart';

/// Refactored cloud-login screen — build() ≤ 30 lines.
///
/// The existing [CloudLoginPage] in `lib/pages/` is untouched
/// until routing is migrated in a later phase.
class CloudLoginScreen extends StatefulWidget {
  const CloudLoginScreen({super.key});

  @override
  State<CloudLoginScreen> createState() => _CloudLoginScreenState();
}

class _CloudLoginScreenState extends State<CloudLoginScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _deptCtrl     = TextEditingController();
  final _cloud        = CloudService();

  bool    _isLoading    = false;
  bool    _isSignUp     = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (final c in [_emailCtrl, _passwordCtrl, _nameCtrl, _deptCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      if (_isSignUp) {
        await _cloud.signUp(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          displayName: _nameCtrl.text.trim(),
          department:  _deptCtrl.text.trim(),
        );
      } else {
        await _cloud.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
      if (mounted) context.navigateTo(RouteConstants.cloudSessions);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: CloudLoginForm(
                  formKey:      _formKey,
                  emailCtrl:    _emailCtrl,
                  passwordCtrl: _passwordCtrl,
                  nameCtrl:     _nameCtrl,
                  deptCtrl:     _deptCtrl,
                  isSignUp:     _isSignUp,
                  isLoading:    _isLoading,
                  errorMessage: _errorMessage,
                  onSubmit:     _submit,
                  onToggleMode: () => setState(() => _isSignUp = !_isSignUp),
                  onBack:       () => context.navigateTo(RouteConstants.home),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
