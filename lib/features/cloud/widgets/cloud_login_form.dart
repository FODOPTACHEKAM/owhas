import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Stateless card form for cloud sign-in / sign-up.
/// All state is owned by [CloudLoginScreen]; this widget is pure presentation.
class CloudLoginForm extends StatelessWidget {
  const CloudLoginForm({
    super.key,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.nameCtrl,
    required this.deptCtrl,
    required this.isSignUp,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onBack,
  });

  final GlobalKey<FormState>   formKey;
  final TextEditingController  emailCtrl;
  final TextEditingController  passwordCtrl;
  final TextEditingController  nameCtrl;
  final TextEditingController  deptCtrl;
  final bool                   isSignUp;
  final bool                   isLoading;
  final String?                errorMessage;
  final VoidCallback           onSubmit;
  final VoidCallback           onToggleMode;
  final VoidCallback           onBack;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Padding(
        padding: AppSpacing.paddingXl,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize:        MainAxisSize.min,
            crossAxisAlignment:  CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, cs),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                _buildErrorBox(errorMessage!),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (isSignUp) ...[
                _field(
                  controller:  nameCtrl,
                  label:       'Full Name',
                  icon:        Icons.person,
                  validator:   (v) => v?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                _field(controller: deptCtrl, label: 'Department', icon: Icons.school),
                const SizedBox(height: AppSpacing.md),
              ],
              _field(
                controller:   emailCtrl,
                label:        'Email',
                icon:         Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                controller:  passwordCtrl,
                label:       'Password',
                icon:        Icons.lock,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (isSignUp && v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: Colors.white,
                  padding: AppSpacing.verticalMd,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width:  20,
                        child:  CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isSignUp ? 'Create Account' : 'Sign In',
                        style: context.textStyles.titleMedium?.semiBold,
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onToggleMode,
                child: Text(
                  isSignUp
                      ? 'Already have an account? Sign In'
                      : 'Need an account? Sign Up',
                ),
              ),
              TextButton(onPressed: onBack, child: const Text('Back to Home')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ColorScheme cs) => Column(
    children: [
      Icon(Icons.cloud, size: 64, color: cs.primary),
      const SizedBox(height: AppSpacing.md),
      Text(
        isSignUp ? 'Create Cloud Account' : 'Cloud Login',
        style:     context.textStyles.headlineMedium?.semiBold,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Access your attendance records from anywhere',
        style:     context.textStyles.bodyMedium?.withColor(Colors.grey[600]!),
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _buildErrorBox(String message) => Container(
    padding:    AppSpacing.paddingMd,
    decoration: BoxDecoration(
      color:        Colors.red[50],
      borderRadius: BorderRadius.circular(AppRadius.md),
      border:       Border.all(color: Colors.red[200]!),
    ),
    child: Text(
      message,
      style:     TextStyle(color: Colors.red[700]),
      textAlign: TextAlign.center,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String                label,
    required IconData              icon,
    TextInputType?                 keyboardType,
    bool                           obscureText = false,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      obscureText:  obscureText,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon),
        border:     OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      validator: validator,
    );
  }
}
