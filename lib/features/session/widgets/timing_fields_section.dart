import 'package:flutter/material.dart';
import '../../../theme.dart';

/// Responsive 2-column grid of session timing inputs.
///
/// Collapses to a single column when viewport width < 680 dp.
class TimingFieldsSection extends StatelessWidget {
  const TimingFieldsSection({
    super.key,
    required this.durationController,
    required this.gracePeriodController,
    required this.connectionTimeController,
    required this.maxAttendanceController,
  });

  final TextEditingController durationController;
  final TextEditingController gracePeriodController;
  final TextEditingController connectionTimeController;
  final TextEditingController maxAttendanceController;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const gap = AppSpacing.md;
        final fw = constraints.maxWidth < 680
            ? double.infinity
            : (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing:    gap,
          runSpacing: gap,
          children: [
            _field(durationController, 'Session Duration (minutes)',
                'How long the session stays open', Icons.hourglass_top, 'min',
                _durationValidator, fw),
            _field(gracePeriodController, 'Grace Period (minutes)',
                'Late arrival tolerance', Icons.timer, 'min',
                _numberValidator, fw),
            _field(connectionTimeController, 'Required Connection Time (minutes)',
                'Minimum time to stay connected', Icons.wifi, 'min',
                _numberValidator, fw),
            _field(maxAttendanceController, 'Maximum Attendance Count',
                'Total number of sessions', Icons.calendar_today, null,
                _numberValidator, fw),
          ],
        );
      },
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon,
    String? suffix,
    String? Function(String?) validator,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller:   ctrl,
        keyboardType: TextInputType.number,
        decoration:   InputDecoration(
          labelText:  label,
          hintText:   hint,
          border:     const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          suffixText: suffix,
        ),
        validator: validator,
      ),
    );
  }

  String? _durationValidator(String? v) {
    if (v?.isEmpty ?? true) return 'Required';
    if (int.tryParse(v!) == null) return 'Must be a number';
    if (int.parse(v) <= 0) return 'Must be greater than 0';
    return null;
  }

  String? _numberValidator(String? v) {
    if (v?.isEmpty ?? true) return 'Required';
    if (int.tryParse(v!) == null) return 'Must be a number';
    return null;
  }
}
