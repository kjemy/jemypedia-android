import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';
import '../../core/services/wordpress_service.dart';
import '../../core/services/hls_proxy_service.dart';
class ProtectedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? keyToken;
  final int? lessonId;
  final String title;
  final String? watermarkText;
  final String? watermarkImageUrl;
  final int watermarkImageSize;
  final VoidCallback? onLessonCompleted;
  final VoidCallback? onVideoEnded;

  const ProtectedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.keyToken,
    this.lessonId,
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

class _ProtectedVideoPlayerState extends State<ProtectedVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorDetail = '';
  bool _hasMarkedCompleted = false;
  late SecurityService _securityService;
  Timer? _watchTimer;
  double _lastLoggedPosition = 0.0;

  @override
  void initState() {
    super.initState();
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
      if (completed) {
        widget.onVideoEnded?.call();
      }
    });

    _securityService = Provider.of<SecurityService>(context, listen: false);
    _securityService.addListener(_onSecurityChanged);
    _initPlayer();
    _startWatchTimer();
  }

  void _startWatchTimer() {
    if (widget.lessonId == null) return;
    
    _watchTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!_isInitialized || !_player.state.playing) return;
      
      final currentPos = _player.state.position.inSeconds.toDouble();
      if (currentPos > _lastLoggedPosition) {
        final deltaMinutes = (currentPos - _lastLoggedPosition) / 60.0;
        _lastLoggedPosition = currentPos;
        
        try {
          final wpService = Provider.of<WordPressService>(context, listen: false);
          final result = await wpService.logWatchTime(widget.lessonId!, deltaMinutes);
          
          final code = result['code'] as String? ?? '';
          final isLimitExceeded = result['success'] == false && 
              (code == 'limit_exceeded' || code.contains('limit'));
          
          if (isLimitExceeded) {
            timer.cancel();
            _player.pause();
            if (mounted) {
              final msg = result['message'] as String? ?? 
                  'لقد تجاوزت الحد الأقصى للمشاهدة المسموح به لهذا الدرس.';
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E2030),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.timer_off_rounded, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'انتهى وقت المشاهدة',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    msg,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                    textAlign: TextAlign.right,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: const Text(
                        'حسناً، خروج',
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Failed to log watch time: $e');
        }
      }
    });
  }


  bool _isSecurityDialogShowing = false;

  void _onSecurityChanged() async {
    if (_securityService.isSecurityCompromised) {
      _player.pause();
      if (!_isSecurityDialogShowing && mounted) {
        _isSecurityDialogShowing = true;

        final bloodyRed = const Color(0xFF8A0303);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => PopScope(
            canPop: false,
            child: Consumer<SecurityService>(
              builder: (dialogCtx, secService, _) {
                final checks = [
                  {
                    'text': 'توصيل سماعات الأذن السلكية (مطلوب سماعة سلكية)',
                    'isOk': secService.isWiredHeadsetOn,
                  },
                  {
                    'text': 'إيقاف تشغيل البلوتوث (Bluetooth)',
                    'isOk': !secService.isBluetoothEnabled,
                  },
                  {
                    'text': 'إيقاف الكاست، الميرور، وأي اتصال بأجهزة أو شاشات خارجية',
                    'isOk': !secService.isExternalDisplayConnected,
                  },
                  {
                    'text': 'إيقاف أي برنامج لتسجيل الشاشة أو الصوت',
                    'isOk': !secService.isBlacklistedProcessRunning,
                  },
                  {
                    'text': 'إيقاف تسجيل أو تصوير الشاشة (Screen Recording)',
                    'isOk': !secService.isScreenRecording,
                  },
                  {
                    'text': 'إغلاق أي أداة أو تطبيق قد يتعارض مع عمل التطبيق (محاكي، تصحيح أخطاء)',
                    'isOk': !(secService.isRooted || secService.isEmulator || secService.isDebuggerConnected),
                  },
                ];

                // If all checks are ok, automatically close the dialog!
                if (!secService.isSecurityCompromised) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.of(dialogCtx).pop();
                  });
                }

                return AlertDialog(
                  backgroundColor: const Color(0xFF1E2030),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.warning_rounded, color: bloodyRed, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تم اكتشاف اشتباه في تحايل على التطبيق',
                          style: TextStyle(color: bloodyRed, fontSize: 15, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'لضمان استمرار عمل التطبيق، يُرجى القيام بما يلي:',
                          textDirection: TextDirection.rtl,
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        ...checks.map((check) {
                          final bool isOk = check['isOk'] as bool;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: isOk ? Colors.greenAccent : bloodyRed,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    check['text'] as String,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      color: isOk ? Colors.white70 : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isOk ? FontWeight.normal : FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        Row(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.gavel_rounded, color: bloodyRed.withOpacity(0.8), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تنبيه قانوني:\nأي محاولة للتحايل على هذا التطبيق أو انتهاك حقوق المحتوى، بأي شكل من الأشكال، تُعدّ جريمة يُعاقب عليها القانون. وقد تم تسجيل هذه المحاولة وحفظها.',
                                textDirection: TextDirection.rtl,
                                style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: Text(
                        'خروج من الدرس',
                        style: TextStyle(color: bloodyRed, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        _isSecurityDialogShowing = false;
        
        if (_securityService.isSecurityCompromised && mounted) {
           Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  void didUpdateWidget(ProtectedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _hasMarkedCompleted = false;
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    try {
      final rawUrl = widget.videoUrl.trim();
      debugPrint("--- VIDEO PLAYER DEBUG ---");
      debugPrint("Original URL: $rawUrl");

      // Reset state
      if (mounted) {
        setState(() {
          _hasError = false;
          _isInitialized = false;
        });
      }

      // Pass the session key token to the proxy so it can inject
      // it as x-key-token header for AES-128 encrypted HLS .key file requests.
      if (widget.keyToken != null && widget.keyToken!.isNotEmpty) {
        hlsProxy.setKeyToken(widget.keyToken);
        debugPrint("Key Token set in proxy: ${widget.keyToken}");
      }

      // Route the video URL through our local HLS proxy.
      // The proxy injects ALL security headers (x-app-token, x-key-token, Referer, etc.)
      // into EVERY request: the .m3u8 manifest, the .key file, and all .ts segments.
      // This is the ONLY reliable way to pass headers for AES-128 encrypted HLS.
      final proxyUrl = hlsProxy.isRunning
          ? hlsProxy.proxyUrl(rawUrl)
          : rawUrl;

      debugPrint("Proxy URL: $proxyUrl");

      await _player.open(Media(proxyUrl), play: true);

      // Some versions of media_kit might need an explicit play call
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
    _watchTimer?.cancel();
    _securityService.removeListener(_onSecurityChanged);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 64),
                const SizedBox(height: 16),
                const Text('Playback Error',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text(_errorDetail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() { _hasError = false; _isInitialized = false; });
                    _initPlayer();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
              const Text(
                "جاري تحضير الفيديو...",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                "Preparing video...",
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // مشغل الفيديو مع تعريف fullscreen مخصص يحتوي على العلامة المائية
        Video(
          controller: _controller,
          controls: MaterialVideoControls,
          onEnterFullscreen: () async {
            // فتح شاشة fullscreen مخصصة تحتوي على العلامة المائية
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
        // العلامة المائية فوق الفيديو في الوضع العادي (غير fullscreen)
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

// ─── صفحة Fullscreen مخصصة تحتوي على العلامة المائية ──────────────────────────
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
    // إخفاء شريط الحالة عند دخول Fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // تدوير الشاشة أفقياً
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // إعادة كل شيء لحالته عند الخروج من Fullscreen
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
          // الفيديو في وضع Fullscreen
          Video(
            controller: widget.controller,
            controls: MaterialVideoControls,
            onExitFullscreen: () async {
              Navigator.pop(context);
            },
          ),
          // العلامة المائية فوق الفيديو في وضع Fullscreen ✅
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
  State<_DynamicWatermarkWidget> createState() => _DynamicWatermarkWidgetState();
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
            // Image watermark
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
            // Text watermark
            if (widget.watermarkText != null && widget.watermarkText!.isNotEmpty) ...
              [
                if (widget.watermarkImageUrl != null) const SizedBox(height: 6),
                Text(
                  widget.watermarkText!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: color == Colors.black ? Colors.white54 : Colors.black54, blurRadius: 4)
                    ]
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

