import 'package:flutter/material.dart';

import '../service_forms/service_form_screen.dart';

/// طلب قطعة غيار — مربوط بنفس API استمارات الموقع (katina/v1/service-forms/parts).
class PartsRequestFormScreen extends StatelessWidget {
  const PartsRequestFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ServiceFormScreen(formId: 'parts');
  }
}
