import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flux_localization/flux_localization.dart';
import 'package:flux_ui/flux_ui.dart';
import 'package:provider/provider.dart';

import '../../common/constants.dart';
import '../../common/tools.dart';

class PartsRequestFormScreen extends StatefulWidget {
  const PartsRequestFormScreen({super.key});

  @override
  State<PartsRequestFormScreen> createState() => _PartsRequestFormScreenState();
}

class _PartsRequestFormScreenState extends State<PartsRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _carNameController = TextEditingController();
  final _modelController = TextEditingController();
  final _partNameController = TextEditingController();
  
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  void dispose() {
    _carNameController.dispose();
    _modelController.dispose();
    _partNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      printLog('[PartsRequestForm] Error picking image: $e');
      if (mounted) {
        Tools.showSnackBar(
          ScaffoldMessenger.of(context),
          S.of(context).somethingWrong,
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      printLog('[PartsRequestForm] Error taking photo: $e');
      if (mounted) {
        Tools.showSnackBar(
          ScaffoldMessenger.of(context),
          S.of(context).somethingWrong,
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text(S.of(context).gallery),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('الكاميرا'),
                onTap: () {
                  Navigator.of(context).pop();
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      Tools.showSnackBar(
        ScaffoldMessenger.of(context),
        'يرجى رفع صورة لقطعة الغيار',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use default email
      const email = 'info@katina.ly';

      // Prepare email subject and body
      final subject = 'طلب قطعة غيار - ${_carNameController.text}';
      final body = '''
اسم السيارة: ${_carNameController.text}
الموديل: ${_modelController.text}
اسم قطعة الغيار: ${_partNameController.text}

---
تم إرسال هذا الطلب من تطبيق كاتينا
''';

      // Create mailto URL
      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      // Launch email client
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        
        if (mounted) {
          Tools.showSnackBar(
            ScaffoldMessenger.of(context),
            'تم فتح تطبيق البريد الإلكتروني. يرجى إرفاق الصورة وإرسال الرسالة.',
          );
          
          // Clear form after a delay
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _carNameController.clear();
              _modelController.clear();
              _partNameController.clear();
              setState(() {
                _selectedImage = null;
              });
            }
          });
        }
      } else {
        if (mounted) {
          Tools.showSnackBar(
            ScaffoldMessenger.of(context),
            'لا يمكن فتح تطبيق البريد الإلكتروني. يرجى إرسال البيانات إلى: $email',
          );
        }
      }
    } catch (e) {
      printLog('[PartsRequestForm] Error sending email: $e');
      if (mounted) {
        Tools.showSnackBar(
          ScaffoldMessenger.of(context),
          S.of(context).somethingWrong,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب قطعة غيار'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'يرجى ملء البيانات التالية لطلب قطعة الغيار',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Car Name Field
                TextFormField(
                  controller: _carNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم السيارة *',
                    hintText: 'أدخل اسم السيارة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.directions_car),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال اسم السيارة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Model Field
                TextFormField(
                  controller: _modelController,
                  decoration: InputDecoration(
                    labelText: 'الموديل *',
                    hintText: 'أدخل موديل السيارة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال الموديل';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Part Name Field
                TextFormField(
                  controller: _partNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم قطعة الغيار *',
                    hintText: 'أدخل اسم قطعة الغيار المطلوبة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.build),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال اسم قطعة الغيار';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Image Upload Section
                Text(
                  'صورة قطعة الغيار *',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                
                GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: _selectedImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 48,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اضغط لرفع صورة',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),
                
                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'إرسال الطلب',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

