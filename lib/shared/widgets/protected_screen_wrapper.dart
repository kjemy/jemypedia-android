import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';

class ProtectedScreenWrapper extends StatelessWidget {
  final Widget child;

  const ProtectedScreenWrapper({super.key, required this.child});

  String _getBreachTitle(SecurityService s) {
    if (s.isRooted) return 'جهاز مخترق (Rooted Device)';
    if (s.isEmulator) return 'بيئة وهمية (Emulator/VM)';
    if (s.isDebuggerConnected) return 'محاولة تفكيك (Debugger Detected)';
    if (s.isExternalDisplayConnected) return 'شاشة خارجية (External Display)';
    return 'تهديد أمني مكتشف';
  }

  String _getBreachMessage(SecurityService s) {
    if (s.isRooted) {
      return 'تم اكتشاف أن جهازك مفتوح الصلاحيات (Rooted/Jailbroken). لا يمكن تشغيل التطبيق على أجهزة مخترقة لحماية المحتوى المدفوع.';
    }
    if (s.isEmulator) {
      return 'تم اكتشاف تشغيل التطبيق داخل محاكي أو بيئة وهمية (Emulator/VM/BlueStacks). هذا السلوك محظور.';
    }
    if (s.isDebuggerConnected) {
      return 'تم اكتشاف محاولة فحص أو تفكيك التطبيق عبر برنامج Debugger. تم إيقاف التطبيق حمايةً للمحتوى وحقوق الملكية الفكرية.';
    }
    if (s.isExternalDisplayConnected) {
      return 'تم اكتشاف توصيل شاشة خارجية أو مشاركة الشاشة (HDMI/Mirroring). يرجى الفصل للمتابعة.';
    }
    return 'تم اكتشاف تهديد أمني غير معروف.';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityService>(
      builder: (context, securityService, _) {
        if (securityService.isSecurityCompromised) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security_update_warning, color: Colors.redAccent, size: 80),
                    const SizedBox(height: 20),
                    Text(
                      _getBreachTitle(securityService),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _getBreachMessage(securityService),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'عدم الالتزام بشروط الاستخدام يعرضك للمساءلة القانونية.\nجميع الحقوق محفوظة © Jemypedia 2026',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Colors.white30, fontSize: 12, height: 1.5),
                    ),
                  ],
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

