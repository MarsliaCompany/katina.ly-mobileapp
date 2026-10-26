import 'package:flutter/widgets.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:inspireui/inspireui.dart' show StringExtension;

import 'string_ext.dart';

typedef _MessageResolver = String Function(S localization);

class _FriendlyMessageMapping {
  const _FriendlyMessageMapping(this.pattern, this.resolver);

  final RegExp pattern;
  final _MessageResolver resolver;
}

extension StringMessageExt on String {
  static final _exceptionPrefix = RegExp(r'^Exception:\s*', caseSensitive: false);
  static final _linkRegex =
      RegExp(r'<a[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true);
  static final _htmlRegex = RegExp(r'<[^>]+>', caseSensitive: false, multiLine: true);
  static final _whitespaceRegex = RegExp(r'\s+');

  static final _friendlyMappings = <_FriendlyMessageMapping>[
    _FriendlyMessageMapping(
      RegExp(r'(username|email).*(password).*(incorrect|invalid)',
          caseSensitive: false),
      (s) => s.userNameInCorrect,
    ),
    _FriendlyMessageMapping(
      RegExp(r'email( address)? already (in use|registered)', caseSensitive: false),
      (s) => s.emailAlreadyInUse,
    ),
    _FriendlyMessageMapping(
      RegExp(r'account (is )?disabled', caseSensitive: false),
      (s) => s.accountIsPendingApproval,
    ),
    _FriendlyMessageMapping(
      RegExp(r'could not create account', caseSensitive: false),
      (s) => s.registerErrorSyncAccount,
    ),
  ];

  String improveMessage(BuildContext context) {
    if (contains('[firebase_auth/email-already-in-use]')) {
      return S.of(context).emailAlreadyInUse;
    }

    return this;
  }

  String beautifyMessage(BuildContext context) {
    final localization = S.of(context);
    var formatted = trim();
    if (formatted.isEmpty) {
      return localization.somethingWrong;
    }

    formatted = formatted.replaceFirst(_exceptionPrefix, '');
    formatted = _cleanExceptionArtifacts(formatted);
    formatted = formatted.replaceAllMapped(_linkRegex, (match) => match.group(1) ?? '');
    formatted = formatted.replaceAll(_htmlRegex, ' ');
    formatted = formatted.unescape();
    formatted = formatted.replaceAll('&nbsp;', ' ');
    formatted = formatted.replaceAll(_whitespaceRegex, ' ').trim();
    formatted = formatted.improveMessage(context);

    for (final mapping in _friendlyMappings) {
      if (mapping.pattern.hasMatch(formatted)) {
        return mapping.resolver(localization);
      }
    }

    if (formatted.isEmpty) {
      return localization.somethingWrong;
    }

    return formatted;
  }

  static String _cleanExceptionArtifacts(String value) {
    final htmlTagRegex = RegExp(r'<[^>]+>', caseSensitive: false);
    final whitespaceRegex = RegExp(r'\s+');

    var cleaned = value.trim();
    if (cleaned.isEmpty) {
      return cleaned;
    }

    cleaned = cleaned.replaceAll(htmlTagRegex, ' ');
    cleaned = cleaned.unescape();
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll(whitespaceRegex, ' ').trim();
    return cleaned;
  }
}

extension NullableStringMessageExt on String? {
  String beautifyMessage(BuildContext context) {
    final value = (this ?? '').trim();
    if (value.isEmpty) {
      return S.of(context).somethingWrong;
    }
    return value.beautifyMessage(context);
  }
}
