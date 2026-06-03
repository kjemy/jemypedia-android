import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';

class ProtectedScreenWrapper extends StatelessWidget {
  final Widget child;

  const ProtectedScreenWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityService>(
      builder: (context, securityService, _) {
        if (securityService.isSecurityCompromised) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security_update_warning, color: Colors.redAccent, size: 80),
                    SizedBox(height: 20),
                    Text(
                      'تم اكتشاف توصيل بشاشة خارجية أو محاولة تسجيل.',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'يرجى فصل الجهاز عن العرض العام أو إيقاف أي برامج لتسجيل الشاشة. عدم الالتزام يعرضك للمساءلة القانونية.',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
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
