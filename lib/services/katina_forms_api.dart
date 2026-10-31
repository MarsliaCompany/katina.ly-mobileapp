import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'service_config.dart';

class KatinaFormField {
  final String name;
  final String label;
  final String type;
  final bool required;
  final List<String> options;

  KatinaFormField({
    required this.name,
    required this.label,
    required this.type,
    required this.required,
    required this.options,
  });

  factory KatinaFormField.fromJson(Map<String, dynamic> json) {
    return KatinaFormField(
      name: '${json['name'] ?? ''}',
      label: '${json['label'] ?? ''}',
      type: '${json['type'] ?? 'text'}',
      required: json['required'] == true,
      options: (json['options'] is List)
          ? (json['options'] as List).map((e) => '$e').toList()
          : const [],
    );
  }
}

class KatinaServiceForm {
  final String id;
  final String title;
  final String slug;
  final String image;
  final int pageId;
  final String pageUrl;
  final List<KatinaFormField> fields;

  KatinaServiceForm({
    required this.id,
    required this.title,
    required this.slug,
    required this.image,
    required this.pageId,
    required this.pageUrl,
    required this.fields,
  });

  factory KatinaServiceForm.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    return KatinaServiceForm(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      image: '${json['image'] ?? ''}',
      pageId: int.tryParse('${json['page_id'] ?? 0}') ?? 0,
      pageUrl: '${json['page_url'] ?? ''}',
      fields: fieldsRaw is List
          ? fieldsRaw
              .whereType<Map>()
              .map((e) => KatinaFormField.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

class KatinaCaptcha {
  final String token;
  final String image;
  final String code;

  KatinaCaptcha({
    required this.token,
    required this.image,
    required this.code,
  });
}

class KatinaFormsApi {
  static String get _base =>
      '${ServerConfig().url}/wp-json/katina/v1/service-forms';

  static Future<List<KatinaServiceForm>> listForms() async {
    final res = await http.get(Uri.parse(_base));
    if (res.statusCode != 200) {
      throw Exception('تعذر تحميل الاستمارات (${res.statusCode})');
    }
    final data = jsonDecode(res.body);
    final forms = data is Map ? data['forms'] : null;
    if (forms is! List) return [];
    return forms
        .whereType<Map>()
        .map((e) => KatinaServiceForm.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<KatinaServiceForm> getForm(String id) async {
    final res = await http.get(Uri.parse('$_base/$id'));
    if (res.statusCode != 200) {
      throw Exception('الاستمارة غير موجودة');
    }
    final data = jsonDecode(res.body);
    final form = data is Map ? data['form'] : null;
    if (form is! Map) {
      throw Exception('بيانات الاستمارة غير صالحة');
    }
    return KatinaServiceForm.fromJson(Map<String, dynamic>.from(form));
  }

  static Future<KatinaCaptcha> getCaptcha(String id) async {
    final res = await http.get(Uri.parse('$_base/$id/captcha'));
    if (res.statusCode != 200) {
      throw Exception('تعذر تحميل رمز التحقق');
    }
    final data = jsonDecode(res.body);
    if (data is! Map) {
      throw Exception('رمز التحقق غير صالح');
    }
    return KatinaCaptcha(
      token: '${data['token'] ?? ''}',
      image: '${data['image'] ?? ''}',
      code: '${data['code'] ?? ''}',
    );
  }

  static Future<String> submit({
    required String id,
    required Map<String, String> fields,
    required String captchaToken,
    required String captchaInput,
    Map<String, List<int>>? files,
    Map<String, String>? fileNames,
  }) async {
    final uri = Uri.parse('$_base/$id/submit');
    final req = http.MultipartRequest('POST', uri);
    req.fields['captcha_token'] = captchaToken;
    req.fields['captcha_input'] = captchaInput;
    fields.forEach((k, v) => req.fields[k] = v);

    if (files != null) {
      for (final entry in files.entries) {
        final name = fileNames?[entry.key] ?? '${entry.key}.jpg';
        req.files.add(
          http.MultipartFile.fromBytes(
            entry.key,
            entry.value,
            filename: name,
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }
    }

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final data = jsonDecode(res.body.isEmpty ? '{}' : res.body);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (data is Map && data['success'] == true) {
        return '${data['message'] ?? 'تم الإرسال بنجاح'}';
      }
    }

    String err = 'تعذر إرسال الطلب';
    if (data is Map) {
      if (data['message'] != null) {
        err = '${data['message']}';
      } else if (data['code'] != null) {
        err = '${data['message'] ?? data['code']}';
      }
    }
    throw Exception(err);
  }
}
