import 'package:flutter/material.dart';
import 'package:flux_ui/flux_ui.dart';

import '../../screens/base_screen.dart';

/// Simple Splash Screen - صفحة بداية بسيطة بصورة واحدة تملأ الشاشة
/// 
/// هذه الشاشة تعرض صورة واحدة تأخذ مساحة الشاشة بالكامل
/// بدون أي تعقيدات أو عناصر إضافية
class SimpleSplashScreen extends StatefulWidget {
  /// مسار الصورة - قم بتعديله حسب موقع صورتك
  /// مثال: 'assets/images/splash_screen.jpg'
  final String imagePath;
  
  /// الدالة التي يتم تنفيذها بعد انتهاء مدة العرض
  final Function? onNextScreen;
  
  /// مدة عرض الشاشة بالميلي ثانية (افتراضيًا 3 ثواني)
  final int duration;
  
  /// لون الخلفية (في حال تأخر تحميل الصورة)
  final Color backgroundColor;

  const SimpleSplashScreen({
    super.key,
    required this.imagePath,
    this.onNextScreen,
    this.duration = 3000,
    this.backgroundColor = Colors.white,
  });

  @override
  BaseScreen<SimpleSplashScreen> createState() => _SimpleSplashScreenState();
}

class _SimpleSplashScreenState extends BaseScreen<SimpleSplashScreen> {
  @override
  void afterFirstLayout(BuildContext context) {
    // الانتقال للشاشة التالية بعد انتهاء المدة المحددة
    Future.delayed(Duration(milliseconds: widget.duration), () {
      if (mounted) {
        widget.onNextScreen?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: FluxImage(
          imageUrl: widget.imagePath,
          // BoxFit.cover لتغطية الشاشة بالكامل
          fit: BoxFit.cover,
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
        ),
      ),
    );
  }
}
