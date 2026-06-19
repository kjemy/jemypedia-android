import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/theme/app_colors.dart';

// ─── قناة الاتصال الأمنية مع Android Native ─────────────────────────────────
const _securityChannel = MethodChannel('com.jemy.academy/security');
const _securityEvents  = EventChannel('com.jemy.academy/security_events');

class ProtectedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? watermarkText;
  final String? watermarkImageUrl;
  final int watermarkImageSize;
  final VoidCallback? onLessonCompleted;
  final VoidCallback? onVideoEnded;

  const ProtectedVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.watermarkText,
    this.watermarkImageUrl,
    this.watermarkImageSize = 120,
    this.onLessonCompleted,
    this.onVideoEnded,
  });

  @override
  State<ProtectedVideoPlayer> createState() => _ProtectedVideoPlayerState();
}

class _ProtectedVideoPlayerState extends State<ProtectedVideoPlayer>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorDetail = '';
  bool _hasMarkedCompleted = false;

  // ─── حالة الحماية ────────────────────────────────────────────────────────
  bool _isRecordingDetected = false;
  StreamSubscription? _securitySubscription;
  Timer? _periodicSecurityCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _player = Player();
    _controller = VideoController(_player);

    _player.stream.position.listen((position) {
      final duration = _player.state.duration;
      if (duration.inSeconds > 0 && !_hasMarkedCompleted) {
        if (position.inSeconds / duration.inSeconds >= 0.85) {
          _hasMarkedCompleted = true;
          widget.onLessonCompleted?.call();
        }
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed) widget.onVideoEnded?.call();
    });

    _initPlayer();
    _startSecurityGuard();
  }

  @override
  void didUpdateWidget(ProtectedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _hasMarkedCompleted = false;
      _initPlayer();
    }
  }

  // ─── تهيئة نظام الحماية الأمنية ──────────────────────────────────────────
  void _startSecurityGuard() {
    // الاستماع للأحداث الأمنية من Android Native (EventChannel)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        _securitySubscription = _securityEvents
            .receiveBroadcastStream()
            .listen(
          (event) {
            if (event is Map) {
              final type = event['type'] as String?;
              if (type == 'screen_recording_detected') {
                _onRecordingDetected();
              } else if (type == 'screen_recording_stopped') {
                _onRecordingStopped();
              }
            }
          },
          onError: (e) => debugPrint('Security event error: $e'),
        );
      } catch (e) {
        debugPrint('Security EventChannel error: $e');
      }

      // فحص دوري إضافي كل ثانية كطبقة احتياطية
      _periodicSecurityCheck = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _checkSecurityState(),
      );
    }
  }

  // ─── فحص حالة الأمان (طبقة احتياطية) ────────────────────────────────────
  Future<void> _checkSecurityState() async {
    if (!mounted) return;
    try {
      final isRecording = await _securityChannel
          .invokeMethod<bool>('isScreenRecording') ?? false;
      if (isRecording && !_isRecordingDetected) {
        _onRecordingDetected();
      } else if (!isRecording && _isRecordingDetected) {
        _onRecordingStopped();
      }
    } catch (e) {
      // تجاهل أخطاء الفحص الدوري
    }
  }

  // ─── عند اكتشاف تسجيل الشاشة ─────────────────────────────────────────────
  void _onRecordingDetected() {
    if (!mounted) return;
    debugPrint('🚨 SECURITY: Screen recording detected! Stopping video...');

    setState(() => _isRecordingDetected = true);

    // 1) إيقاف الفيديو فوراً (Pause)
    _player.pause();

    // 2) كتم الصوت من مستوى الـ Player
    _player.setVolume(0.0);

    // 3) طلب كتم الصوت من Android (AudioManager)
    if (!kIsWeb && Platform.isAndroid) {
      _securityChannel.invokeMethod('muteAudio').catchError((e) {});
    }

    // 4) إغلاق التطبيق بعد 2 ثانية (إظهار رسالة تحذير أولاً)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isRecordingDetected) {
        if (!kIsWeb && Platform.isAndroid) {
          _securityChannel.invokeMethod('stopApp').catchError((e) {});
        }
      }
    });
  }

  // ─── عند إيقاف تسجيل الشاشة ──────────────────────────────────────────────
  void _onRecordingStopped() {
    if (!mounted) return;
    debugPrint('✅ SECURITY: Screen recording stopped. Resuming...');

    setState(() => _isRecordingDetected = false);

    // إعادة الصوت
    _player.setVolume(100.0);

    if (!kIsWeb && Platform.isAndroid) {
      _securityChannel.invokeMethod('unmuteAudio').catchError((e) {});
    }

    // استئناف الفيديو
    _player.play();
  }

  Future<void> _initPlayer() async {
    try {
      final rawUrl = widget.videoUrl.trim();
      debugPrint("--- VIDEO PLAYER DEBUG ---");
      debugPrint("URL: $rawUrl");

      if (mounted) {
        setState(() {
          _hasError = false;
          _isInitialized = false;
        });
      }

      await _player.open(Media(rawUrl), play: true);
      _player.play();

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint("Video Player Error: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorDetail = "Error loading video: ${e.toString()}";
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _securitySubscription?.cancel();
    _periodicSecurityCheck?.cancel();
    // إعادة الصوت عند إغلاق المشغل
    if (!kIsWeb && Platform.isAndroid) {
      _securityChannel.invokeMethod('unmuteAudio').catchError((e) {});
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ─── شاشة التحذير الأمنية (عند اكتشاف التسجيل) ──────────────────────
    if (_isRecordingDetected) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // أيقونة تحذير متحركة
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.2),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, scale, child) => Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.redAccent,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '⚠️ تحذير أمني',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'تم اكتشاف محاولة تسجيل الشاشة\nسيتم إغلاق التطبيق تلقائياً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: Colors.redAccent,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jemy Academy - محمي بحقوق الملكية',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text('Playback Error',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 8),
                Text(_errorDetail,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasError = false;
                      _isInitialized = false;
                    });
                    _initPlayer();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: const Text('Retry Loading'),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.accentNeon),
              const SizedBox(height: 20),
              const Text("Attempting to connect...",
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // مشغل الفيديو مع Fullscreen مخصص
        Video(
          controller: _controller,
          controls: MaterialVideoControls,
          onEnterFullscreen: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullscreenVideoPage(
                  controller: _controller,
                  watermarkText: widget.watermarkText,
                  watermarkImageUrl: widget.watermarkImageUrl,
                  watermarkImageSize: widget.watermarkImageSize,
                ),
              ),
            );
          },
        ),
        // العلامة المائية
        if (widget.watermarkText != null || widget.watermarkImageUrl != null)
          Positioned.fill(
            child: _DynamicWatermarkWidget(
              watermarkText: widget.watermarkText,
              watermarkImageUrl: widget.watermarkImageUrl,
              watermarkImageSize: widget.watermarkImageSize,
            ),
          ),
      ],
    );
  }
}

// ─── صفحة Fullscreen مع حماية ──────────────────────────────────────────────
class _FullscreenVideoPage extends StatefulWidget {
  final VideoController controller;
  final String? watermarkText;
  final String? watermarkImageUrl;
  final int watermarkImageSize;

  const _FullscreenVideoPage({
    required this.controller,
    this.watermarkText,
    this.watermarkImageUrl,
    this.watermarkImageSize = 120,
  });

  @override
  State<_FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<_FullscreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Video(
            controller: widget.controller,
            controls: MaterialVideoControls,
            onExitFullscreen: () async => Navigator.pop(context),
          ),
          if (widget.watermarkText != null || widget.watermarkImageUrl != null)
            Positioned.fill(
              child: _DynamicWatermarkWidget(
                watermarkText: widget.watermarkText,
                watermarkImageUrl: widget.watermarkImageUrl,
                watermarkImageSize: widget.watermarkImageSize,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── العلامة المائية الديناميكية ───────────────────────────────────────────
class _DynamicWatermarkWidget extends StatefulWidget {
  final String? watermarkText;
  final String? watermarkImageUrl;
  final int watermarkImageSize;
  const _DynamicWatermarkWidget({
    required this.watermarkText,
    this.watermarkImageUrl,
    this.watermarkImageSize = 120,
  });

  @override
  State<_DynamicWatermarkWidget> createState() =>
      _DynamicWatermarkWidgetState();
}

class _DynamicWatermarkWidgetState extends State<_DynamicWatermarkWidget> {
  final Random _random = Random();
  Timer? _timer;
  bool _isMasterVisible = false;

  Alignment _align1 = Alignment.topLeft;
  Alignment _align2 = Alignment.bottomRight;

  double _opacity1 = 0.35;
  double _opacity2 = 0.40;

  @override
  void initState() {
    super.initState();
    _startAnimationCycle();
    _startMasterVisibilityCycle();
  }

  void _startMasterVisibilityCycle() async {
    while (mounted) {
      if (mounted) setState(() => _isMasterVisible = false);
      await Future.delayed(const Duration(minutes: 3));
      if (!mounted) break;
      setState(() => _isMasterVisible = true);
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  void _startAnimationCycle() {
    _align1 = _getRandomAlignment();
    _align2 = _getRandomAlignment();

    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) return;
      setState(() {
        _align1 = _getRandomAlignment();
        _align2 = _getRandomAlignment();
        _opacity1 = _random.nextBool() ? 0.35 : 0.0;
        _opacity2 = _random.nextBool() ? 0.40 : 0.0;
        if (_opacity1 == 0.0 && _opacity2 == 0.0) _opacity1 = 0.35;
      });
    });
  }

  Alignment _getRandomAlignment() {
    return Alignment(
      _random.nextDouble() * 2 - 1,
      _random.nextDouble() * 2 - 1,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.watermarkText == null && widget.watermarkImageUrl == null) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(seconds: 2),
        opacity: _isMasterVisible ? 1.0 : 0.0,
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(seconds: 15),
              curve: Curves.linear,
              alignment: _align1,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 3),
                opacity: _opacity1,
                child: _buildWatermark(Colors.white, 26),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(seconds: 12),
              curve: Curves.linear,
              alignment: _align2,
              child: AnimatedOpacity(
                duration: const Duration(seconds: 3),
                opacity: _opacity2,
                child: _buildWatermark(Colors.black, 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermark(Color color, double fontSize) {
    return Transform.rotate(
      angle: -0.2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.watermarkImageUrl != null)
              Opacity(
                opacity: 0.6,
                child: Image.network(
                  widget.watermarkImageUrl!,
                  width: widget.watermarkImageSize.toDouble(),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (widget.watermarkText != null &&
                widget.watermarkText!.isNotEmpty) ...[
              if (widget.watermarkImageUrl != null) const SizedBox(height: 6),
              Text(
                widget.watermarkText!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                        color: color == Colors.black
                            ? Colors.white54
                            : Colors.black54,
                        blurRadius: 4)
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
