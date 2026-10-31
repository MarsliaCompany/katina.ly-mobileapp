import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/katina_forms_api.dart';

class ServiceFormScreen extends StatefulWidget {
  final String formId;

  const ServiceFormScreen({super.key, required this.formId});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _selectValues = <String, String?>{};
  final _files = <String, File?>{};
  KatinaServiceForm? _form;
  KatinaCaptcha? _captcha;
  final _captchaController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final form = await KatinaFormsApi.getForm(widget.formId);
      final captcha = await KatinaFormsApi.getCaptcha(widget.formId);
      for (final f in form.fields) {
        if (f.type == 'select') {
          _selectValues[f.name] = null;
        } else if (f.type != 'file') {
          _controllers[f.name] = TextEditingController();
        }
      }
      if (!mounted) return;
      setState(() {
        _form = form;
        _captcha = captcha;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshCaptcha() async {
    try {
      final captcha = await KatinaFormsApi.getCaptcha(widget.formId);
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _captchaController.clear();
      });
    } catch (_) {}
  }

  Future<void> _pickFile(String name) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _files[name] = File(picked.path);
    });
  }

  Future<void> _submit() async {
    if (_form == null || _captcha == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final fields = <String, String>{};
      final fileBytes = <String, List<int>>{};
      final fileNames = <String, String>{};

      for (final f in _form!.fields) {
        if (f.type == 'file') {
          final file = _files[f.name];
          if (file != null) {
            fileBytes[f.name] = await file.readAsBytes();
            fileNames[f.name] = file.path.split('/').last;
          }
        } else if (f.type == 'select') {
          fields[f.name] = _selectValues[f.name] ?? '';
        } else {
          fields[f.name] = _controllers[f.name]?.text.trim() ?? '';
        }
      }

      final msg = await KatinaFormsApi.submit(
        id: widget.formId,
        fields: fields,
        captchaToken: _captcha!.token,
        captchaInput: _captchaController.text.trim(),
        files: fileBytes.isEmpty ? null : fileBytes,
        fileNames: fileNames.isEmpty ? null : fileNames,
      );

      if (!mounted) return;
      Tools.showSnackBar(ScaffoldMessenger.of(context), msg);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      Tools.showSnackBar(ScaffoldMessenger.of(context), '$e');
      await _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildCaptchaImage() {
    final c = _captcha;
    if (c == null) return const SizedBox.shrink();
    if (c.image.startsWith('data:image')) {
      final b64 = c.image.split(',').last;
      return Image.memory(
        base64Decode(b64),
        width: 160,
        height: 52,
        fit: BoxFit.cover,
      );
    }
    if (c.code.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF0F172A),
        child: Text(
          c.code,
          style: const TextStyle(
            color: Color(0xFFFCC376),
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_form?.title ?? 'استمارة الخدمة'),
        backgroundColor: theme.primaryColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_form!.image.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _form!.image,
                                height: 140,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          ..._form!.fields.map((f) {
                            if (f.type == 'file') {
                              final file = _files[f.name];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${f.label}${f.required ? ' *' : ''}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _pickFile(f.name),
                                      icon: const Icon(Icons.photo),
                                      label: Text(file == null
                                          ? 'اختيار صورة'
                                          : 'تم اختيار صورة'),
                                    ),
                                    if (file != null) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          file,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }
                            if (f.type == 'select') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: DropdownButtonFormField<String>(
                                  value: _selectValues[f.name],
                                  decoration: InputDecoration(
                                    labelText:
                                        '${f.label}${f.required ? ' *' : ''}',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: f.options
                                      .map((o) => DropdownMenuItem(
                                            value: o,
                                            child: Text(o),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _selectValues[f.name] = v),
                                  validator: (v) {
                                    if (f.required &&
                                        (v == null || v.isEmpty)) {
                                      return 'مطلوب';
                                    }
                                    return null;
                                  },
                                ),
                              );
                            }
                            final isArea = f.type == 'textarea';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextFormField(
                                controller: _controllers[f.name],
                                maxLines: isArea ? 4 : 1,
                                keyboardType: f.type == 'tel'
                                    ? TextInputType.phone
                                    : f.type == 'email'
                                        ? TextInputType.emailAddress
                                        : TextInputType.text,
                                decoration: InputDecoration(
                                  labelText:
                                      '${f.label}${f.required ? ' *' : ''}',
                                  border: const OutlineInputBorder(),
                                ),
                                validator: (v) {
                                  if (f.required &&
                                      (v == null || v.trim().isEmpty)) {
                                    return 'مطلوب';
                                  }
                                  return null;
                                },
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Text(
                            'أدخل الرمز الظاهر في الصورة *',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildCaptchaImage(),
                              IconButton(
                                onPressed: _refreshCaptcha,
                                icon: const Icon(Icons.refresh),
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: _captchaController,
                                  decoration: const InputDecoration(
                                    hintText: 'الرمز',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'مطلوب'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: theme.primaryColor,
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'إرسال',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
