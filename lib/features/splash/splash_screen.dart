import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/core/providers/courses_provider.dart';
import 'package:jemypedia_app/core/providers/auth_provider.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:jemypedia_app/features/home/ui/home_screen.dart';
import 'package:jemypedia_app/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ─── Animation Controllers ───────────────────────────────────────────────
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _particleController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressValue;

  String _statusText = 'جارٍ التحميل...';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Logo pop-in
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _logoOpacity = CurvedAnimation(parent: _logoController, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));

    // Text slide-up
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textOpacity = CurvedAnimation(parent: _textController, curve: Curves.easeIn)
        .drive(Tween(begin: 0.0, end: 1.0));
    _textSlide = CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic)
        .drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero));

    // Particle/glow pulse
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _progressValue = CurvedAnimation(parent: _progressController, curve: Curves.easeInOut)
        .drive(Tween(begin: 0.0, end: 1.0));
  }

  Future<void> _startSequence() async {
    // Step 1: Animate logo
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));

    // Step 2: Animate text
    await _textController.forward();

    // Step 3: Start progress bar & load data
    _progressController.forward();

    if (!mounted) return;
    setState(() => _statusText = 'جارٍ تحميل البيانات...');

    // Load initial data
    final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Run data loading alongside minimum display time
    await Future.wait([
      _loadData(coursesProvider, authProvider),
      Future.delayed(const Duration(milliseconds: 2800)),
    ]);

    if (!mounted) return;
    setState(() => _statusText = 'أهلاً بك!');

    await Future.delayed(const Duration(milliseconds: 400));

    // Step 4: Navigate to HomeScreen
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _loadData(CoursesProvider coursesProvider, AuthProvider authProvider) async {
    try {
      // Fetch ticker + courses + categories
      if (!mounted) return;
      setState(() => _statusText = 'جارٍ تحميل الكورسات...');
      await coursesProvider.fetchCourses();

      // Auto-login if credentials are saved
      if (!mounted) return;
      final creds = await authProvider.getSavedCredentials();
      if (creds != null) {
        setState(() => _statusText = 'جارٍ التحقق من حسابك...');
        final hwid = await WordPressService.getDeviceId();
        final userData = await coursesProvider.verifyUserSubscription(
          creds['email']!,
          creds['password']!,
          hwid,
        );
        if (!mounted) return;
        if (userData != null && userData['success'] == true) {
          await authProvider.login(
            creds['email']!,
            creds['password']!,
            rememberMe: true,
            userData: userData,
          );
        } else if (userData != null && userData['success'] == false) {
          await authProvider.logout();
          // Show device limit error after navigation (via SnackBar on HomeScreen)
          if (mounted && userData['message'] != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      userData['message'].toString(),
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                    ),
                    backgroundColor: Colors.red.shade800,
                    duration: const Duration(seconds: 6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Splash load error: $e');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Animated gradient background ──────────────────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              final glow = _particleController.value;
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2 + glow * 0.3,
                    colors: [
                      AppColors.primary.withOpacity(0.35 + glow * 0.15),
                      Colors.black,
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Decorative circles ────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentNeon.withOpacity(0.07 + _particleController.value * 0.06),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.10 + _particleController.value * 0.08),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo with glow
              AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) {
                  return ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentNeon.withOpacity(0.25 + _particleController.value * 0.2),
                              blurRadius: 40 + _particleController.value * 20,
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.accentNeon.withOpacity(0.3 + _particleController.value * 0.2),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.school_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // App Name + tagline
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Colors.white, AppColors.accentNeon],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'Jemypedia',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'منصة التعليم الاحترافي',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.6),
                          fontFamily: 'Cairo',
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Progress bar ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 50),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _progressValue,
                      builder: (_, __) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progressValue.value,
                          minHeight: 3,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentNeon),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _statusText,
                        key: ValueKey(_statusText),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Version tag
              Text(
                'v$appVersion',
                style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }
}
