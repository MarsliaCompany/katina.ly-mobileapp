import 'package:flutter/foundation.dart';

/// Normalizes Libyan phone numbers into the local format expected by the backend.
///
/// - Removes any non-digit characters.
/// - Strips international prefixes such as +218 or 00218.
/// - Ensures numbers starting with 91 or 92 are prefixed with 0.
/// - Preserves an existing leading zero if present.
String normalizeLibyaPhoneNumber(String? rawInput) {
  if (rawInput == null || rawInput.isEmpty) {
    return '';
  }

  var digitsOnly = rawInput.replaceAll(RegExp(r'[^0-9]'), '');

  if (digitsOnly.startsWith('00218')) {
    digitsOnly = digitsOnly.substring(5);
  } else if (digitsOnly.startsWith('218')) {
    digitsOnly = digitsOnly.substring(3);
  }

  if (digitsOnly.isEmpty) {
    return '';
  }

  if (digitsOnly.startsWith('0')) {
    return digitsOnly;
  }

  if (digitsOnly.startsWith('91') ||
      digitsOnly.startsWith('92') ||
      digitsOnly.length == 9) {
    return '0$digitsOnly';
  }

  return digitsOnly;
}
