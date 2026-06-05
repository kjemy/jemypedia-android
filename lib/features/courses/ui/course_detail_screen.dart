import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/animated_hover_card.dart';
import '../../../shared/widgets/protected_video_player.dart';
import '../../../shared/widgets/course_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/courses_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/favorites_provider.dart';
import '../../../core/utils/hwid_service.dart';
import '../models/course_model.dart';
import '../../../core/services/wordpress_service.dart';
import '../../quizzes/models/quiz_model.dart';
import '../../quizzes/ui/quiz_screen.dart';
import '../../materials/models/material_model.dart';
import '../../materials/ui/materials_section.dart';
import '../../../core/localization/app_localizations.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  String? _currentVideoUrl;
  String? _currentKeyToken;
  bool _isFetchingVideo = false;
  int? _selectedLessonId;
  LessonModel? _selectedLesson;
  Map<String, dynamic>? _certificateTemplate;
  List<QuizModel> _quizzes = [];
  List<MaterialModel> _courseMaterials = [];
  bool _isLoadingQuizzes = false;
  bool _isLoadingMaterials = false;
  final WordPressService _api = WordPressService();
  Map<String, dynamic> _watermarkConfig = {'text': 'jemytrade.com', 'image_url': null, 'image_size': 120};

  @override
  void initState() {
    super.initState();
    _quizzes = widget.course.quizzes;
    _fetchCertTemplate();
    _fetchQuizzes();
    _fetchMaterials();
    // Use addPostFrameCallback to safely access Provider after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchWatermarkConfig();
    });
  }

  Future<void> _fetchWatermarkConfig() async {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.userEmail != null) {
      final config = await _api.getWatermarkConfig(auth.userEmail!);
      if (mounted) setState(() => _watermarkConfig = config);
    }
  }

  Future<void> _fetchQuizzes() async {
    // If we already have embedded quizzes, we can still try to fetch fresh ones,
    // but the embedded ones ensure visibility if the API call is blocked.
    if (_quizzes.isEmpty) setState(() => _isLoadingQuizzes = true);
    
    final data = await _api.getCourseQuizzes(widget.course.id);
    if (mounted && data.isNotEmpty) {
      setState(() {
        _quizzes = data;
        _isLoadingQuizzes = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingQuizzes = false);
    }
  }

  Future<void> _fetchMaterials() async {
    setState(() => _isLoadingMaterials = true);
    final data = await _api.getCourseMaterials(widget.course.id);
    if (mounted) {
      setState(() {
        _courseMaterials = data;
        _isLoadingMaterials = false;
      });
    }
  }

  Future<void> _fetchCertTemplate() async {
    final data = await _api.getCertificateTemplate(widget.course.id);
    if (mounted) {
      setState(() => _certificateTemplate = data);
    }
  }

  Future<void> _claimCertificate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isLoggedIn || auth.userEmail == null) return;

    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await _api.issueCertificate(auth.userEmail!, widget.course.id);
    
    if (mounted) {
      Navigator.pop(context); // close loading
      if (result != null && result['success'] == true) {
        final viewUrl = result['view_url'];
        if (await canLaunchUrl(Uri.parse(viewUrl))) {
          await launchUrl(Uri.parse(viewUrl), mode: LaunchMode.externalApplication);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to issue certificate. Please try again later.')));
      }
    }
  }

  Future<void> _playLesson(LessonModel lesson) async {
    setState(() {
      _isFetchingVideo = true;
      _selectedLessonId = lesson.id;
      _selectedLesson = lesson;
    });

    try {
      final hwid = await HwidService.getDeviceFingerprint();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final provider = Provider.of<CoursesProvider>(context, listen: false);

      final email = authProvider.userEmail ?? '';
      final password = authProvider.userPassword ?? '';

      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please log in again.')),
        );
        setState(() { _isFetchingVideo = false; });
        return;
      }

      final result = await provider.getLessonVideoUrl(lesson.id, email, password, hwid);
      
      if (mounted) {
        setState(() {
          _currentVideoUrl = result['success'] ? result['video_url'] : null;
          _currentKeyToken = result['success'] ? result['key_token'] : null;
          _isFetchingVideo = false;
        });
        
        if (!result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to fetch video.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isFetchingVideo = false; });
      }
    }
  }

  void _playNextLesson() {
    if (_selectedLessonId == null) return;
    
    final currentIndex = widget.course.lessons.indexWhere((l) => l.id == _selectedLessonId);
    if (currentIndex != -1 && currentIndex < widget.course.lessons.length - 1) {
      final nextLesson = widget.course.lessons[currentIndex + 1];
      
      final provider = Provider.of<CoursesProvider>(context, listen: false);
      final isUnlocked = provider.unlockedCourses.contains(widget.course.id) || widget.course.isFree;
      final locale = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
      
      if (isUnlocked || nextLesson.isFreePreview) {
        _playLesson(nextLesson);
      } else {
        _showLockedDialog(context, locale);
      }
    }
  }

  void _showLockedDialog(BuildContext context, String locale) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.orange),
            const SizedBox(width: 10),
            Text(locale == 'ar' ? 'درس مدفوع' : 'Premium Lesson', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(locale == 'ar' ? 'هذا الدرس يتطلب اشتراكاً للمشاهدة. يرجى الاشتراك لفتح الكورس بالكامل.' : 'This lesson requires a subscription to view. Please subscribe to unlock the full course.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(locale == 'ar' ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchWooCommerceCheckout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(locale == 'ar' ? 'اشترك الآن' : 'Subscribe Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isLoadingQuizzes = true);
    final updatedCourse = await _api.getCourseById(widget.course.id);
    if (updatedCourse != null && mounted) {
      setState(() {
        _quizzes = updatedCourse.quizzes;
        _isLoadingQuizzes = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'تم التحديث بنجاح' : 'Refreshed successfully')),
      );
    } else {
      setState(() => _isLoadingQuizzes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, locale),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeader(locale, textColor),
                      Text(locale == 'ar' ? 'عدد الدروس: ${widget.course.lessons.length}' : 'Lessons: ${widget.course.lessons.length}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildInstructorInfo(locale, textColor),
                  const SizedBox(height: 20),
                  _buildBrief(locale, textColor),
                  const SizedBox(height: 25),
                  _buildProgressBar(isDark, textColor, locale),
                  const SizedBox(height: 30),
                  
                  // Materials Section
                  if (_isLoadingMaterials)
                    const Center(child: CircularProgressIndicator())
                  else if (_courseMaterials.isNotEmpty)
                    MaterialsSection(materials: _courseMaterials),
                    
                  const SizedBox(height: 30),
                  
                  // Quizzes Section (Pre-course)
                  Consumer<CoursesProvider>(
                    builder: (context, provider, child) {
                      bool isUnlocked = provider.unlockedCourses.contains(widget.course.id) || widget.course.isFree;
                      return _buildQuizzes(locale, textColor, isUnlocked, true);
                    },
                  ),
                  
                  Text(locale == 'ar' ? 'محتوى الكورس' : 'Course Syllabus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 15),
                  Consumer<CoursesProvider>(
                    builder: (context, provider, child) {
                      bool isUnlocked = provider.unlockedCourses.contains(widget.course.id) || widget.course.isFree;
                      return _buildLessonList(context, locale, isDark, isUnlocked);
                    },
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Quizzes Section (Post-course)
                  Consumer<CoursesProvider>(
                    builder: (context, provider, child) {
                      bool isUnlocked = provider.unlockedCourses.contains(widget.course.id) || widget.course.isFree;
                      return _buildQuizzes(locale, textColor, isUnlocked, false);
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, String locale) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: _handleRefresh,
          tooltip: 'Refresh',
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
                  if (_currentVideoUrl != null || widget.course.introVideoUrl.isNotEmpty)
              Positioned.fill(
                child: ProtectedVideoPlayer(
                  key: ValueKey(_currentVideoUrl ?? widget.course.introVideoUrl),
                  videoUrl: _currentVideoUrl ?? widget.course.introVideoUrl,
                  keyToken: _currentKeyToken,
                  title: _selectedLesson?.getLocalizedTitle(locale) ?? AppLocalizations.tr(context, 'preview'),
                  watermarkText: (_watermarkConfig['text'] as String?)?.isNotEmpty == true
                      ? _watermarkConfig['text'] as String
                      : null,
                  watermarkImageUrl: _watermarkConfig['image_url'] as String?,
                  watermarkImageSize: (_watermarkConfig['image_size'] as int?) ?? 120,
                  onLessonCompleted: () {
                    if (_selectedLessonId != null) {
                      Provider.of<CoursesProvider>(context, listen: false).markLessonCompleted(_selectedLessonId!);
                    }
                  },
                  onVideoEnded: () {
                    if (_currentVideoUrl != null) _playNextLesson();
                  },
                ),
              )
            else ...[
            CourseImage(
                url: widget.course.coverImageUrl, 
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
              Container(color: Colors.black45),
              Center(
                child: _isFetchingVideo 
                  ? const CircularProgressIndicator(color: AppColors.accentNeon)
                  : const Icon(Icons.play_circle_fill, color: AppColors.accentNeon, size: 80),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String locale, Color textColor) {
    return Expanded(
      child: Row(
        children: [
          Expanded(
            child: Text(widget.course.getLocalizedTitle(locale), 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
          ),
          Consumer<FavoritesProvider>(
            builder: (context, favs, _) {
              final isFav = favs.isCourseFavorite(widget.course.id);
              return IconButton(
                icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.white : Colors.white70),
                onPressed: () => favs.toggleCourseFavorite(widget.course.id),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInstructorInfo(String locale, Color textColor) {
    return Row(
      children: [
        const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(widget.course.getLocalizedInstructor(locale), style: TextStyle(color: textColor.withOpacity(0.7))),
        const SizedBox(width: 20),
        const Icon(Icons.access_time, size: 18, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(locale == 'ar' ? '${widget.course.duration} ساعات' : '${widget.course.duration} Hours', style: TextStyle(color: textColor.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildBrief(String locale, Color textColor) {
    return Text(widget.course.getLocalizedBrief(locale),
      style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 14, height: 1.5));
  }

  Widget _buildProgressBar(bool isDark, Color textColor, String locale) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(locale == 'ar' ? 'تقدمك في الكورس' : 'Your Progress', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Text('${(widget.course.progress * 100).toInt()}%', style: const TextStyle(color: AppColors.accentNeon, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: widget.course.progress,
              backgroundColor: isDark ? Colors.white10 : Colors.black12,
              color: AppColors.accentNeon,
              minHeight: 8,
            ),
          ),
          if (_certificateTemplate != null) ...[
            const SizedBox(height: 15),
            Builder(builder: (context) {
              final minProg = (_certificateTemplate!['min_progress'] ?? 80).toDouble() / 100.0;
              final canClaim = widget.course.progress >= minProg;
              
              return ElevatedButton.icon(
                onPressed: canClaim ? _claimCertificate : null,
                icon: Icon(canClaim ? Icons.workspace_premium_rounded : Icons.lock_clock_rounded),
                label: Text(canClaim 
                    ? (locale == 'ar' ? 'احصل على شهادتك' : 'Claim Your Certificate')
                    : (locale == 'ar' ? 'أكمل ${((minProg - widget.course.progress) * 100).toInt()}% أخرى للحصول على الشهادة' : 'Finish ${((minProg - widget.course.progress) * 100).toInt()}% more to get Certificate')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: canClaim ? Colors.amber : Colors.grey.withOpacity(0.1),
                  foregroundColor: canClaim ? Colors.black : textColor.withOpacity(0.3),
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: canClaim ? 4 : 0,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuizzes(String locale, Color textColor, bool isUnlocked, bool isPre) {
    if (_isLoadingQuizzes) return const SizedBox.shrink();
    if (_quizzes.isEmpty) return const SizedBox.shrink();

    final filtered = _quizzes.where((q) {
      if (isPre) return q.type == 'before_course' || q.type == 'free_level';
      return q.type == 'after_course';
    }).toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...filtered.map((q) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _buildQuizBanner(q, locale, q.type != 'after_course'),
        )),
      ],
    );
  }

  Widget _buildQuizBanner(QuizModel quiz, String locale, bool isPreCourse) {
    return AnimatedHoverCard(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => QuizScreen(quiz: quiz, onPassed: () {
            // Refresh cert template or progress if needed
            _fetchCertTemplate();
          }),
        ));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.2), AppColors.accentNeon.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.accentNeon.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.quiz_rounded, color: AppColors.accentNeon, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quiz.type == 'free_level'
                      ? (locale == 'ar' ? 'اختبار تقييم المستوى' : 'Level Assessment')
                      : isPreCourse 
                        ? (locale == 'ar' ? 'اختبار تمهيدي' : 'Pre-Course Quiz')
                        : (locale == 'ar' ? 'الاختبار النهائي' : 'Final Exam'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    quiz.getLocalizedTitle(locale),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(locale == 'ar' ? Icons.arrow_back_ios : Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }



  Widget _buildLessonList(BuildContext context, String locale, bool isDark, bool isUnlocked) {
    if (widget.course.lessons.isEmpty && _quizzes.isEmpty) {
      return const Center(child: Text('No content available.', style: TextStyle(color: Colors.grey)));
    }
    
    List<Widget> items = [];

    // Add before_course quizzes at the start of the syllabus
    final beforeQuizzes = _quizzes.where((q) => q.type == 'before_course' || q.type == 'free_level').toList();
    for (final q in beforeQuizzes) {
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: _buildQuizBanner(q, locale, isUnlocked),
      ));
    }

    for (int i = 0; i < widget.course.lessons.length; i++) {
      final lesson = widget.course.lessons[i];
      items.add(_buildLessonItem(context, (i + 1).toString(), lesson, locale, isDark, isUnlocked));
      
      // Check for after_lesson quizzes
      final lessonQuizzes = _quizzes.where((q) => q.type == 'after_lesson' && q.lessonId == lesson.id).toList();
      for (final q in lessonQuizzes) {
        items.add(Padding(
          padding: const EdgeInsets.only(left: 30, right: 10, bottom: 15, top: 5),
          child: _buildQuizBanner(q, locale, isUnlocked),
        ));
      }
    }

    // Add after_course quizzes at the end
    final afterQuizzes = _quizzes.where((q) => q.type == 'after_course').toList();
    for (final q in afterQuizzes) {
      items.add(Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 15),
        child: _buildQuizBanner(q, locale, isUnlocked),
      ));
    }
    
    return Column(children: items);
  }

  Future<void> _launchWooCommerceCheckout() async {
    final String productId = widget.course.wooProductId;
    final Uri url = productId.isNotEmpty 
        ? Uri.parse('https://www.jemypedia.com/?p=$productId')
        : Uri.parse('https://www.jemypedia.com/shop');
        
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode == 'ar'
          ? 'تعذر فتح رابط الاشتراك.'
          : 'Could not open subscription link.'
      )));
      }
    }
  }

  Widget _buildLessonItem(BuildContext context, String index, LessonModel lesson, String locale, bool isDark, bool isUnlocked) {
    final bool isSelected = _selectedLessonId == lesson.id;
    final bool canPlay = isUnlocked || lesson.isFreePreview;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedHoverCard(
        onTap: () {
          if (canPlay) {
            _playLesson(lesson);
          } else {
            _showLockedDialog(context, locale);
          }
        },
        child: GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 35, height: 35,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accentNeon : AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text(index, style: TextStyle(color: isSelected ? Colors.black : AppColors.primary, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(lesson.getLocalizedTitle(locale), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (lesson.isFreePreview && !isUnlocked)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(5)),
                            child: Text(locale == 'ar' ? 'مجاني' : 'FREE', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    Text('${lesson.duration} ${locale == 'ar' ? 'دقيقة' : 'mins'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Consumer<FavoritesProvider>(
                builder: (context, favs, _) {
                  final isFav = favs.isLessonFavorite(lesson.id);
                  return IconButton(
                    icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 18, color: isFav ? Colors.white : Colors.white30),
                    onPressed: () => favs.toggleLessonFavorite(lesson.id),
                  );
                },
              ),
              if (lesson.hasMaterials)
                IconButton(
                  icon: const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.accentNeon),
                  onPressed: () => _showLessonMaterials(lesson, locale),
                  tooltip: locale == 'ar' ? 'تحميل المواد' : 'Download Materials',
                ),
              Icon(canPlay ? (isSelected ? Icons.pause_circle_filled : Icons.play_circle_outline) : Icons.lock_outline, 
                color: canPlay ? (isSelected ? AppColors.accentNeon : Colors.grey) : Colors.orange.withOpacity(0.8)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLessonMaterials(LessonModel lesson, String locale) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: FutureBuilder<List<MaterialModel>>(
          future: _api.getLessonMaterials(lesson.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final materials = snapshot.data ?? [];
            if (materials.isEmpty) {
              return SizedBox(height: 100, child: Center(child: Text(locale == 'ar' ? 'لا توجد مواد لهذا الدرس' : 'No materials for this lesson')));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(locale == 'ar' ? 'مواد الدرس' : 'Lesson Materials', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                MaterialsSection(materials: materials),
              ],
            );
          },
        ),
      ),
    );
  }
}
