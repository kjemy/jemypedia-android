import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';

class ProtectedScreenWrapper extends StatelessWidget {
  final Widget child;

  const ProtectedScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const bloodyRed = Color(0xFF8A0303);
    const darkBackground = Color(0xFF0F0F14);

    return Consumer<SecurityService>(
      builder: (context, securityService, _) {
        if (securityService.isSecurityCompromised) {
          return Scaffold(
            backgroundColor: darkBackground,
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    darkBackground,
                    Color(0xFF220A0A),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: bloodyRed.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: bloodyRed.withOpacity(0.3), width: 1.5),
                          ),
                          child: const Icon(
                            Icons.gavel_rounded,
                            color: bloodyRed,
                            size: 72,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'تم اكتشاف اشتباه في تحايل على التطبيق',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: bloodyRed,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'لضمان استمرار عمل التطبيق، يُرجى القيام بما يلي:',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...[
                                'إيقاف تشغيل البلوتوث',
                                'إيقاف الكاست، الميرور، وأي اتصال بأجهزة أو شاشات خارجية',
                                'إيقاف أي برنامج لتسجيل الشاشة أو الصوت',
                                'إغلاق أي أداة أو تطبيق قد يتعارض مع عمل التطبيق',
                              ].map((item) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      textDirection: TextDirection.rtl,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(color: bloodyRed, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item,
                                            textDirection: TextDirection.rtl,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 20),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 12),
                              Row(
                                textDirection: TextDirection.rtl,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.warning_rounded, color: bloodyRed.withOpacity(0.8), size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'تنبيه قانوني:\nأي محاولة للتحايل على هذا التطبيق أو انتهاك حقوق المحتوى، بأي شكل من الأشكال، تُعدّ جريمة يُعاقب عليها القانون. وقد تم تسجيل هذه المحاولة وحفظها.',
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'جميع الحقوق محفوظة © Jemypedia 2026',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        // Safe to show content
        return child;
      },
    );
  }
}

