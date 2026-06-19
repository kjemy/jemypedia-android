import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
import 'package:jemy_academy_app/core/theme/app_colors.dart';
import 'package:win32/win32.dart';
import 'dart:ffi' hide Size;
import 'package:ffi/ffi.dart';
import 'package:jemy_academy_app/shared/widgets/glass_container.dart';
import 'package:jemy_academy_app/features/home/ui/home_screen.dart';
import 'package:jemy_academy_app/core/providers/locale_provider.dart';
import 'package:jemy_academy_app/core/providers/articles_provider.dart';
import 'package:jemy_academy_app/core/providers/courses_provider.dart';
import 'package:jemy_academy_app/core/providers/auth_provider.dart';
import 'package:jemy_academy_app/core/providers/favorites_provider.dart';
import 'package:jemy_academy_app/features/support/ui/chat_screen.dart';
import 'package:media_kit/media_kit.dart';

// ─── قنوات الأمان العامة ───────────────────────────────────────────────────
const _kSecurityChannel = MethodChannel('com.jemy.academy/security');
const _kSecurityEvents  = EventChannel('com.jemy.academy/security_events');

const String appVersion = '2.1.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // مطلوب لتهيئة مشغل الفيديو
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "Jemy Academy",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ─── نظام الحماية الفولاذي (منع التسجيل + كشف Root + حماية الصوت) ─────────
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      // الطبقة 1: FLAG_SECURE (شاشة سوداء عند التسجيل)
      await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);

      // الطبقة 2: كشف Root - إغلاق فوري إذا كان الجهاز مكسور
      try {
        final isRooted = await FlutterJailbreakDetection.jailbroken;
        if (isRooted) {
          debugPrint('🚨 ROOT DETECTED - Closing app immediately.');
          exit(0);
        }
        final devMode = await FlutterJailbreakDetection.developerMode;
        if (devMode) {
          debugPrint('⚠️ Developer mode is ON - user is a developer.');
        }
      } catch (e) {
        debugPrint('Root detection error: $e');
      }

    } else if (Platform.isIOS) {
      await ScreenProtector.preventScreenshotOn();
      // كشف Jailbreak على iOS
      try {
        final isJailbroken = await FlutterJailbreakDetection.jailbroken;
        if (isJailbroken) {
          debugPrint('🚨 JAILBREAK DETECTED - Closing app immediately.');
          exit(0);
        }
      } catch (e) {
        debugPrint('Jailbreak detection error: $e');
      }

    } else if (Platform.isWindows) {
      // حماية ويندوز: WDA_EXCLUDEFROMCAPTURE (0x11) يمنع HDMI والتسجيل
      Timer.periodic(const Duration(milliseconds: 500), (timer) {
        try {
          final windowTitle = "Jemy Academy".toNativeUtf16();
          final hwnd = FindWindow(nullptr, windowTitle);
          free(windowTitle);
          if (hwnd != 0) {
            SetWindowDisplayAffinity(hwnd, 0x00000011);
            if (timer.tick > 5) timer.cancel();
            debugPrint("Windows Security: Screen capture blocked.");
          }
        } catch (e) {
          debugPrint("Windows Security Error: \$e");
        }
        if (timer.tick > 30) timer.cancel();
      });
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

class JemyAcademyApp extends StatefulWidget {
  const JemyAcademyApp({super.key});

  @override
  State<JemyAcademyApp> createState() => _JemyAcademyAppState();
}

class _JemyAcademyAppState extends State<JemyAcademyApp> {
  StreamSubscription? _globalSecuritySub;
  bool _globalRecordingDetected = false;

  @override
  void initState() {
    super.initState();
    _handleInitialAuth();
    _startGlobalSecurityMonitor();
  }

  /// مراقبة أمنية على مستوى التطبيق كله - تُغلق التطبيق عند أي تسجيل
  void _startGlobalSecurityMonitor() {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _globalSecuritySub = _kSecurityEvents
            .receiveBroadcastStream()
            .listen((event) {
          if (event is Map) {
            final type = event['type'] as String?;
            if (type == 'screen_recording_detected' && !_globalRecordingDetected) {
              _globalRecordingDetected = true;
              debugPrint('🚨 GLOBAL MONITOR: Recording detected - muting and closing app');
              // كتم الصوت فوراً
              _kSecurityChannel.invokeMethod('muteAudio').catchError((_) {});
              // إغلاق التطبيق بعد 3 ثوانٍ (بعد إظهار شاشة التحذير من المشغل)
              Future.delayed(const Duration(seconds: 4), () {
                _kSecurityChannel.invokeMethod('stopApp').catchError((_) => exit(0));
              });
            } else if (type == 'screen_recording_stopped') {
              _globalRecordingDetected = false;
              _kSecurityChannel.invokeMethod('unmuteAudio').catchError((_) {});
            }
          }
        }, onError: (e) => debugPrint('Global security error: $e'));
      } catch (e) {
        debugPrint('Global security monitor init error: $e');
      }
    }
  }

  @override
  void dispose() {
    _globalSecuritySub?.cancel();
    super.dispose();
  }


  Future<void> _handleInitialAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final coursesProvider = Provider.of<CoursesProvider>(context, listen: false);
    
    final creds = await authProvider.getSavedCredentials();
    if (creds != null) {
      final hwid = await HwidService.getDeviceFingerprint();
      final userData = await coursesProvider.verifyUserSubscription(
        creds['email']!, 
        creds['password']!, 
        hwid
      );
      
      if (userData != null && userData['success'] == true) {
        await authProvider.login(
          creds['email']!, 
          creds['password']!, 
          rememberMe: true, 
          userData: userData
        );
      }
    }
    // Always fetch initial content (articles, ticker, etc.)
    await coursesProvider.fetchCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          title: 'Jemy Academy',
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

            return Stack(
              children: [
                widget!,
                // 🚀 Global Floating Chat Icon (Visible on EVERY screen)
                Positioned(
                  bottom: 30,
                  right: 20,
                  child: Material(
                    color: Colors.transparent,
                    child: FloatingActionButton.large(
                      heroTag: 'global_chat_fab',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                        );
                      },
                      backgroundColor: Colors.white,
                      elevation: 20,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF212121), size: 35),
                    ),
                  ),
                ),
              ],
            );
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
          home: const HomeScreen(),
        );
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
                        'assets/images/app_icon.jpg',
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
                              final fingerprint = await HwidService.getDeviceFingerprint();
                              final userData = await coursesProvider.verifyUserSubscription(email, password, fingerprint);
                              
                              if (context.mounted) {
                                setState(() => _isLoading = true); // Keep loading while processing
                                
                                if (userData != null) {
                                  // Mark user as logged in, store credentials if remember me is checked
                                  await authProvider.login(email, password, rememberMe: _rememberMe, userData: userData);
                                  
                                  setState(() => _isLoading = false);
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                                  );
                                } else {
                                  setState(() => _isLoading = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Login Failed. Invalid credentials or network error.')),
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
