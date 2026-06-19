import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/shared/widgets/glass_container.dart';
import 'package:jemypedia_app/features/home/ui/home_screen.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:jemypedia_app/core/providers/articles_provider.dart';
import 'package:jemypedia_app/core/providers/courses_provider.dart';
import 'package:jemypedia_app/core/providers/auth_provider.dart';
import 'package:jemypedia_app/core/providers/favorites_provider.dart';
import 'package:jemypedia_app/core/providers/chat_provider.dart';
import 'package:jemypedia_app/core/services/wordpress_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:jemypedia_app/features/splash/splash_screen.dart';
import 'package:jemypedia_app/core/services/security_service.dart';
import 'package:jemypedia_app/shared/widgets/protected_screen_wrapper.dart';
import 'package:jemypedia_app/core/services/hls_proxy_service.dart';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'dart:io';

const String appVersion = '2.2.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    MediaKit.ensureInitialized(); // مطلوب لتهيئة مشغل الفيديو
  } catch (e) {
    debugPrint("MediaKit initialization error: $e");
  }

  // Start local HLS proxy to inject security headers on all video requests
  await hlsProxy.start();

  // تفعيل نظام الحماية (منع تصوير الشاشة وتسجيل الفيديو)
  if (!kIsWeb) {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await ScreenProtector.preventScreenshotOn();
      }
    } catch (e) {
      debugPrint("Security init error: $e");
    }

    // تفعيل حماية الأندرويد ضد الروت والمحاكيات
    if (Platform.isAndroid) {
      try {
        bool isJailBroken = await FlutterJailbreakDetection.jailbroken;
        
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        bool isRealDevice = androidInfo.isPhysicalDevice;
        
        if (isJailBroken || !isRealDevice) {
          runApp(
            const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: Color(0xFF8B0000), // Dark Red
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security, color: Colors.white, size: 80),
                        SizedBox(height: 20),
                        Text(
                          'Security Violation',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Rooted device or Emulator detected.\nThe application cannot run on this device for security reasons.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          );
          return; // Stop app initialization
        }
      } catch (e) {
        debugPrint("Anti-tamper check failed: $e");
      }
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => ArticlesProvider()),
        ChangeNotifierProvider(create: (_) => CoursesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
      ],
      child: const JemyAcademyApp(),
    ),
  );
}

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark; // Default is Dark

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}


class GlobalSecurityMonitor extends StatefulWidget {
  final Widget child;
  const GlobalSecurityMonitor({super.key, required this.child});
  @override
  State<GlobalSecurityMonitor> createState() => _GlobalSecurityMonitorState();
}

class _GlobalSecurityMonitorState extends State<GlobalSecurityMonitor> {
  static const _securityEvents = EventChannel('jemypedia/security_events');
  static const _securityChannel = MethodChannel('jemypedia/security');
  
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isAndroid) {
      _securityEvents.receiveBroadcastStream().listen((event) {
        if (event is Map && event['type'] == 'screen_recording_detected') {
          _securityChannel.invokeMethod('stopApp');
          exit(0);
        }
      });
    }
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

class JemyAcademyApp extends StatefulWidget {
  const JemyAcademyApp({super.key});

  @override
  State<JemyAcademyApp> createState() => _JemyAcademyAppState();
}

class _JemyAcademyAppState extends State<JemyAcademyApp> {
  // No initState needed - SplashScreen handles all loading & auto-login

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return GlobalSecurityMonitor(child: MaterialApp(
          title: 'Jemypedia',
          debugShowCheckedModeBanner: false,
          builder: (context, widget) {
            // Restore ErrorWidget logic
            ErrorWidget.builder = (FlutterErrorDetails details) {
              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                        const SizedBox(height: 20),
                        const Text('Oops! Something went wrong.', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text(details.exception.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())),
                          child: const Text('Reload App'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            };

            return ProtectedScreenWrapper(child: widget!);
          },
          themeMode: themeProvider.themeMode,
          locale: localeProvider.locale,
          supportedLocales: const [
            Locale('en', ''),
            Locale('ar', ''),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.bgLight,
            textTheme: localeProvider.isArabic 
                ? GoogleFonts.cairoTextTheme() 
                : GoogleFonts.interTextTheme(),
            iconTheme: const IconThemeData(color: AppColors.primary, size: 24),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.bgDark,
            textTheme: localeProvider.isArabic 
                ? GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme)
                : GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
            iconTheme: const IconThemeData(color: Colors.white, size: 24),
          ),
          home: const SplashScreen(),
        ));
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final creds = await authProvider.getSavedCredentials();
    if (creds != null) {
      setState(() {
        _emailController.text = creds['email'] ?? '';
        _passwordController.text = creds['password'] ?? '';
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.bgDark, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with Glow
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentNeon.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_icon.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.school_rounded, size: 40, color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Login Glass Card
                  GlassContainer(
                    blur: 20,
                    opacity: 0.1,
                    child: Column(
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 30),
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Email Address',
                            hintStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: const TextStyle(color: Colors.white70),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.white70,
                              ),
                              onPressed: () => setState(() => _obscureText = !_obscureText),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Remember Me Checkbox
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (val) => setState(() => _rememberMe = val ?? false),
                              activeColor: AppColors.accentNeon,
                              side: const BorderSide(color: Colors.white38),
                            ),
                            const Text('Remember Me', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        const SizedBox(height: 30),
                        
                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: const LinearGradient(
                              colors: [AppColors.accentNeon, AppColors.primary],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () async {
                              final email = _emailController.text.trim();
                              final password = _passwordController.text;
                              
                              if (email.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter both email and password.')),
                                );
                                return;
                              }

                              setState(() => _isLoading = true);

                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
                              
                              // Verify subscription via HWID. This also validates the credentials.
                              final fingerprint = await WordPressService.getDeviceId();
                              final userData = await coursesProvider.verifyUserSubscription(email, password, fingerprint);
                              
                              if (context.mounted) {
                                // userData is null = network error
                                // userData['success'] == false = server returned an error (wrong creds, device limit...)
                                // userData['success'] == true  = login OK
                                if (userData != null && userData['success'] == true) {
                                  await authProvider.login(email, password, rememberMe: _rememberMe, userData: userData);
                                  setState(() => _isLoading = false);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                                  );
                                } else {
                                  setState(() => _isLoading = false);
                                  // Show the server error message (Arabic device-limit message, wrong password, etc.)
                                  final errMsg = (userData != null && userData['message'] != null)
                                      ? userData['message'].toString()
                                      : 'فشل تسجيل الدخول. تحقق من الاتصال بالإنترنت أو بيانات الدخول.';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        errMsg,
                                        textDirection: TextDirection.rtl,
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                                      ),
                                      backgroundColor: Colors.red.shade800,
                                      duration: const Duration(seconds: 5),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isLoading 
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          },
                          child: const Text(
                            'Browse as Guest',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

