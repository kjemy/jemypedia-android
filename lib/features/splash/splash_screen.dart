import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/core/providers/courses_provider.dart';
import 'package:jemypedia_app/core/providers/auth_provider.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:jemypedia_app/features/home/ui/home_screen.dart';
import 'package:jemypedia_app/features/main_layout/ui/main_layout.dart';
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
        pageBuilder: (_, __, ___) => const MainLayout(),
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
      body: Center(
        child: FadeTransition(
          opacity: _logoOpacity,
          child: Image.asset(
            'assets/images/splash_logo.jpg',
            width: 250,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
