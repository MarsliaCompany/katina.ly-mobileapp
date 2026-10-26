import 'package:flutter/material.dart';

const _kKatinaSnackBarColor = Color(0xFFFF7000);
const _kKatinaSnackBarDuration = Duration(seconds: 5);

void showKatinaUpdateSnackBar(
  BuildContext context,
  VoidCallback onUpdate, {
  String message = 'تم تحديث البيانات في الخلفية. اضغط تحديث الآن لعرضها.',
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: _kKatinaSnackBarColor,
      duration: _kKatinaSnackBarDuration,
      content: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
      action: SnackBarAction(
        label: 'تحديث الآن',
        textColor: Colors.white,
        onPressed: onUpdate,
      ),
    ),
  );
}
