import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:math' as math;

class ForceUpdateScreen extends StatefulWidget {
  final String requiredVersion;
  final String currentVersion;
  final String updateUrl;

  const ForceUpdateScreen({
    super.key,
    required this.requiredVersion,
    required this.currentVersion,
    required this.updateUrl,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // ❌ يمنع الرجوع تماماً
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.topCenter,
              radius: 1.5,
              colors: [
                AppColors.primary.withOpacity(0.8),
                Colors.black,
                Colors.black,
              ],
            ),
          ),
          child: Stack(
            children: [
              // ─── خلفية دوارة زخرفية ────────────────────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _rotateController,
                  builder: (_, __) => Transform.rotate(
                    angle: _rotateController.value * 2 * math.pi,
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                ),
              ),

              // ─── المحتوى الرئيسي ─────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── الأيقونة المتحركة ──────────────────────────
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        ),
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.accentNeon.withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentNeon.withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            size: 85,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── عنوان رئيسي ──────────────────────────────
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, AppColors.accentNeon],
                        ).createShader(bounds),
                        child: const Text(
                          'App Needs To Update',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── العنوان بالعربي ───────────────────────────
                      Text(
                        'التطبيق يحتاج إلى تحديث',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentNeon,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── بطاقة الرسالة ────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // English
                            Text(
                              'Version ${widget.requiredVersion} is now available.\nYou are using version ${widget.currentVersion}.\nPlease update to continue using Jemypedia.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(color: Colors.white12),
                            ),
                            // Arabic
                            Text(
                              'الإصدار ${widget.requiredVersion} متاح الآن.\nأنت تستخدم الإصدار ${widget.currentVersion}.\nيرجى التحديث للاستمرار في استخدام تطبيق Jemypedia.',
                              textAlign: TextAlign.center,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // ── زر التحديث ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(widget.updateUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 26),
                          label: const Text(
                            'Update Now  |  تحديث الآن',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentNeon,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 12,
                            shadowColor: AppColors.accentNeon.withOpacity(0.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── نص صغير أسفل ─────────────────────────────
                      Text(
                        'www.jemypedia.com',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── رسام الشبكة الخلفية الزخرفية ──────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width * 2; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 2), paint);
    }
    for (double y = 0; y < size.height * 2; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width * 2, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
