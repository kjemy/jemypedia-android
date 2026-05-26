import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/animated_hover_card.dart';
import '../../../shared/widgets/glass_drawer.dart';
import '../../../shared/widgets/course_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:jemypedia_app/core/providers/courses_provider.dart';
import 'package:jemypedia_app/core/providers/favorites_provider.dart';
import 'package:jemypedia_app/core/models/section_model.dart';
import 'package:jemypedia_app/features/courses/ui/course_detail_screen.dart';
import 'package:jemypedia_app/features/courses/models/course_model.dart';
import '../../articles/ui/article_detail_screen.dart';
import '../../articles/models/article_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../main.dart';
import '../../support/ui/chat_screen.dart';
import '../../../core/services/wordpress_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:jemypedia_app/main.dart'; // To get appVersion
import 'force_update_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _tickerController;
  Timer? _tickerTimer;
  double _tickerOffset = 0;

  @override
  void initState() {
    super.initState();
    _tickerController = ScrollController();
    _startTicker();
    
    // Add listener to check version whenever data is updated from server
    Provider.of<CoursesProvider>(context, listen: false).addListener(_checkVersion);
    
    // Initial check in case data is already there
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  bool _forceUpdateRequired = false;

  void _checkVersion() {
    if (!mounted) return;
    final provider = Provider.of<CoursesProvider>(context, listen: false);
    final serverVer = provider.requiredVersion;
    final updateUrl = provider.updateUrl;

    debugPrint("═══ VERSION CHECK ═══");
    debugPrint("Local  : $appVersion");
    debugPrint("Server : $serverVer");
    debugPrint("URL    : $updateUrl");
    debugPrint("═════════════════════");

    if (serverVer.isNotEmpty && serverVer != appVersion) {
      if (!_forceUpdateRequired) {
        setState(() {
          _forceUpdateRequired = true;
        });
      }
    }
  }

  void _startTicker() {
    final provider = Provider.of<CoursesProvider>(context, listen: false);
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (_tickerController.hasClients) {
        // Speed calculation: 1.0 is standard (1px per 30ms). 10.0 from WP = 1.0 here.
        double speedFactor = provider.tickerSpeed / 10.0;
        _tickerOffset += speedFactor;
        if (_tickerOffset >= _tickerController.position.maxScrollExtent) {
          _tickerOffset = 0;
          _tickerController.jumpTo(0);
        } else {
          _tickerController.jumpTo(_tickerOffset);
        }
      }
    });
  }

  @override
  void dispose() {
    // IMPORTANT: Remove listener to avoid memory leaks
    Provider.of<CoursesProvider>(context, listen: false).removeListener(_checkVersion);
    _tickerTimer?.cancel();
    _tickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CoursesProvider>(context);
    final serverVer = provider.requiredVersion;
    
    // 🛡️ THE ABSOLUTE FORCE UPDATE CHECK (Directly in Build)
    if (serverVer.isNotEmpty && serverVer != appVersion) {
      debugPrint("!!! FORCE UPDATE TRIGGERED IN BUILD !!!");
      return ForceUpdateScreen(
        requiredVersion: serverVer,
        currentVersion: appVersion,
        updateUrl: provider.updateUrl,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      drawer: const GlassDrawer(),
      body: Stack(
        children: [
          (provider.isLoading && provider.courses.isEmpty)
              ? const Center(child: CircularProgressIndicator(color: AppColors.accentNeon))
              : (provider.courses.isEmpty)
                  ? _buildErrorPlaceholder(provider)
                  : _buildMainContent(context, provider, auth, isDark, textColor),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(
          Icons.chat_bubble_rounded, 
          color: Color(0xFF212121),
          size: 35,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildErrorPlaceholder(CoursesProvider provider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Colors.black],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 100, color: Colors.white24),
          const SizedBox(height: 20),
          const Text('Failed to load courses', style: TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Check your internet or API connection', style: TextStyle(color: Colors.white30, fontSize: 14)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () => provider.fetchCourses(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Loading Data'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentNeon,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, CoursesProvider provider, AuthProvider auth, bool isDark, Color textColor) {
    return CustomScrollView(
      slivers: [
        _buildAppBar(context, isDark),
        SliverToBoxAdapter(child: _buildTicker(context)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (auth.isLoggedIn) _buildSubscriptionAlert(context),
                const SizedBox(height: 25),
                _buildSectionTitle(AppLocalizations.tr(context, 'popular_categories'), Icons.grid_view, textColor),
                const SizedBox(height: 15),
                _buildDynamicCategoryList(context, textColor),
                const SizedBox(height: 30),
                _buildSectionTitle(AppLocalizations.tr(context, 'continue_learning'), Icons.play_circle_outline, textColor),
                const SizedBox(height: 15),
                _buildContinueLearningItem(context, textColor, isDark),
                const SizedBox(height: 30),
                if (provider.newCourses.isNotEmpty) ...[
                  _buildSectionTitle(AppLocalizations.tr(context, 'new_courses'), Icons.new_releases_outlined, textColor),
                  const SizedBox(height: 15),
                  _buildHorizontalCourseList(context, textColor, provider.newCourses),
                  const SizedBox(height: 30),
                ],
                _buildSectionTitle('Coming Soon', Icons.timelapse_rounded, textColor),
                const SizedBox(height: 15),
                _buildHorizontalCourseList(context, textColor, provider.courses.where((c) => c.badgeStatus['value'] == 'SOON').toList()),
                const SizedBox(height: 30),

                _buildSectionTitle('Recently Updated', Icons.update_rounded, textColor),
                const SizedBox(height: 15),
                _buildHorizontalCourseList(context, textColor, provider.courses.where((c) => c.badgeStatus['value'] == 'UPDATED').toList()),
                const SizedBox(height: 30),

                _buildSectionTitle('Trending Now', Icons.local_fire_department_rounded, textColor),
                const SizedBox(height: 15),
                _buildHorizontalCourseList(context, textColor, provider.courses.reversed.toList()),
                const SizedBox(height: 30),

                // ─── DYNAMIC SECTIONS FROM WORDPRESS ───
                ...provider.sections.map((section) => _buildDynamicSection(context, section, textColor, isDark)),
                
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white10, thickness: 1),
        const SizedBox(height: 25),
        const Text(
          "© 2026-2027 Jemypedia Platform. All Rights Reserved.\nالحقوق محفوظة لمنصة جيميبيديا 2026/2027",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () async {
            final url = Uri.parse('https://www.jemypedia.com');
            if (await launchUrl(url)) {}
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.language_rounded, color: AppColors.accentNeon, size: 16),
              SizedBox(width: 8),
              Text(
                "www.jemypedia.com",
                style: TextStyle(
                  color: AppColors.accentNeon,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            InkWell(
              onTap: () async {
                final url = Uri.parse('mailto:Support@Jemypedia.com');
                if (await launchUrl(url)) {}
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 14),
                  SizedBox(width: 6),
                  Text("Support@Jemypedia.com", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
            InkWell(
              onTap: () async {
                final url = Uri.parse('mailto:Partner@jemypedia.com');
                if (await launchUrl(url)) {}
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.business_center_outlined, color: Colors.white30, size: 14),
                  SizedBox(width: 6),
                  Text("Partner@jemypedia.com", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return AppColors.secondary;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return AppColors.secondary;
    }
  }

  Widget _buildTicker(BuildContext context) {
    final coursesProvider = Provider.of<CoursesProvider>(context);
    return Container(
      height: 40,
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.9),
      child: Center(
        child: ListView(
          controller: _tickerController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                "${coursesProvider.tickerText}  •  باستخدامك للتطبيق فأنت توافق على الشروط والأحكام الموضحة على موقعنا www.jemypedia.com  •  ${coursesProvider.tickerText}",
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicCategoryList(BuildContext context, Color textColor) {
    final categories = Provider.of<CoursesProvider>(context).categories;
    
    if (categories.isEmpty) {
      return Center(child: Text('No categories found.', style: TextStyle(color: textColor.withOpacity(0.5))));
    }
    
    final displayCats = categories;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: displayCats.length,
        itemBuilder: (context, index) {
          final cat = displayCats[index];
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                AnimatedHoverCard(
                  onTap: () => _navigateToCategory(context, cat),
                  child: Container(
                      width: 75,
                      height: 75,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primary.withOpacity(0.6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Center(
                        child: (cat['icon_image'] != null && cat['icon_image'].toString().isNotEmpty)
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: cat['icon_image'],
                                  width: 45,
                                  height: 45,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white12)),
                                errorWidget: (context, url, error) => Icon(getCategoryIcon(cat['icon'] ?? cat['slug']), color: Colors.white, size: 30),
                              ),
                            )
                          : Icon(getCategoryIcon(cat['icon'] ?? cat['slug']), color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(cat['name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _navigateToCategory(BuildContext context, dynamic category) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryExplorerScreen(category: category)),
    );
  }

  void _showLoginRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Login Required', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Please login to access this premium feature.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('LoginNow'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: isDark ? Colors.black : Colors.white,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          onPressed: () => Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            showSearch(context: context, delegate: CourseSearchDelegate());
          },
        ),
        IconButton(
          icon: const Icon(Icons.language_rounded),
          onPressed: () => Provider.of<LocaleProvider>(context, listen: false).toggleLocale(),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
        const SizedBox(width: 15),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/app_icon.png',
                  height: 30,
                  width: 30,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Jemypedia',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 55, bottom: 16, right: 55),
      ),
    );
  }

  Widget _buildSubscriptionAlert(BuildContext context) {
    return AnimatedHoverCard(
      child: GlassContainer(
        color: Colors.red.withOpacity(0.1),
        borderColor: Colors.red.withOpacity(0.3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.tr(context, 'subscription_expiring'),
                style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.redAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color textColor, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accentNeon, size: 22),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(AppLocalizations.tr(context, 'see_all'), style: const TextStyle(color: AppColors.accentNeon)),
          ),
      ],
    );
  }

  Widget _buildContinueLearningItem(BuildContext context, Color textColor, bool isDark) {
    return Consumer<CoursesProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.courses.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accentNeon));
        }
        
        if (provider.courses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 80, color: Colors.white24),
                const SizedBox(height: 20),
                const Text('Failed to load courses', style: TextStyle(color: Colors.white70, fontSize: 18)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => provider.fetchCourses(),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentNeon, foregroundColor: Colors.black),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
        
        final course = provider.courses.first;
        final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

        return AnimatedHoverCard(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)),
            );
          },
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: CourseImage(
                    url: course.coverImageUrl,
                    width: 80,
                    height: 80,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.getLocalizedTitle(locale), 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                      Text(course.getLocalizedInstructor(locale), style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: course.progress,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        color: AppColors.accentNeon,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow_rounded, color: AppColors.accentNeon, size: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalCourseList(BuildContext context, Color textColor, List<CourseModel> courses) {
    if (courses.isEmpty) return Center(child: Text('No courses found', style: TextStyle(color: textColor)));

    final ScrollController scrollController = ScrollController();

    return Consumer<CoursesProvider>(
      builder: (context, provider, child) {
        final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

        return Stack(
          children: [
            SizedBox(
              height: 330,
              child: ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 5),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];
              return Container(
                width: 240,
                margin: const EdgeInsets.only(right: 20),
                child: AnimatedHoverCard(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CourseDetailScreen(course: course)),
                    );
                  },
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Stack(
                                    children: [
                                      CourseImage(
                                        url: course.coverImageUrl,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                      if (course.getLocalizedBadge(locale).isNotEmpty || course.isNew)
                                        Positioned(
                                          top: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _parseHexColor(course.badgeStatus['color']),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(course.getLocalizedBadge(locale).isNotEmpty ? course.getLocalizedBadge(locale) : AppLocalizations.tr(context, 'new'),
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ),
                                        ),
                                      Positioned(
                                        top: 12,
                                        left: 12,
                                        child: Consumer2<CoursesProvider, FavoritesProvider>(
                                          builder: (context, prov, favProv, child) {
                                            final isWatchLater = prov.watchLaterCourseIds.contains(course.id);
                                            final isFavorite = favProv.isCourseFavorite(course.id);
                                            String? catIcon;
                                            final cat = course.categoryIds.isNotEmpty ? prov.getCategoryDetails(course.categoryIds.first) : null;
                                            if (cat != null) catIcon = cat['icon'] ?? cat['slug'];
                                            
                                            return Row(
                                              children: [
                                                // Bookmark (Watch Later)
                                                GestureDetector(
                                                  onTap: () => prov.toggleWatchLater(course.id),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                                    child: Icon(
                                                      isWatchLater ? Icons.bookmark : Icons.bookmark_border,
                                                      color: isWatchLater ? AppColors.accentNeon : Colors.white,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                // Heart (Favorite)
                                                GestureDetector(
                                                  onTap: () => favProv.toggleCourseFavorite(course.id),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                                                    child: Icon(
                                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                                      color: isFavorite ? Colors.white : Colors.white70,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(course.getLocalizedTitle(locale), 
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                              const SizedBox(height: 6),
                              Consumer<CoursesProvider>(
                                builder: (context, prov, child) {
                                  if (course.categoryIds.isNotEmpty) {
                                    final cat = prov.getCategoryDetails(course.categoryIds.first);
                                    if (cat != null) {
                                      return Text(cat['name'] ?? '', style: TextStyle(fontSize: 11, color: AppColors.accentNeon, fontWeight: FontWeight.bold));
                                    }
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: AppColors.accentNeon),
                                  const SizedBox(width: 6),
                                  Text('${course.duration} ${AppLocalizations.tr(context, 'hours')}', 
                                    style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.6))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(course.getLocalizedInstructor(locale), 
                                      maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.7))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (course.price['regular_price'].toString().isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (course.price['on_sale'] == true)
                                      Text("${course.price['regular_price']} ${course.price['currency']}", 
                                        style: TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                    Row(
                                      children: [
                                        Text("${course.price['on_sale'] == true ? course.price['sale_price'] : course.price['regular_price']} ${course.price['currency']}", 
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentNeon)),
                                        const SizedBox(width: 4),
                                        Text(course.getLocalizedAccessPeriod(locale), 
                                          style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5))),
                                      ],
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (courses.length > 1) ...[
          // Left Arrow
          Positioned(
            left: 0,
            top: 330 / 2 - 20,
            child: GestureDetector(
              onTap: () {
                scrollController.animateTo(scrollController.offset - 240, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
              ),
            ),
          ),
          // Right Arrow
          Positioned(
            right: 0,
            top: 330 / 2 - 20,
            child: GestureDetector(
              onTap: () {
                scrollController.animateTo(scrollController.offset + 240, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
              ),
            ),
          ),
        ]
      ],
    );
  },
);
}

  // Articles List hidden
  Widget _buildArticlesList(BuildContext context, Color textColor, bool isDark) {
    return const SizedBox.shrink();
  }


  // Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
  // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ DYNAMIC SECTION FROM WORDPRESS Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Ã¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢ÂÃ¢â€¢Â
  Widget _buildDynamicSection(BuildContext context, SectionModel section, Color textColor, bool isDark) {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    if (section.courses.isEmpty) return const SizedBox.shrink();

    final ScrollController scrollController = ScrollController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          section.getLocalizedTitle(locale), 
          Icons.auto_awesome_rounded, 
          textColor,
          onSeeAll: () {
            if (section.seeAllCategory > 0) {
              final prov = Provider.of<CoursesProvider>(context, listen: false);
              final cat = prov.getCategoryDetails(section.seeAllCategory);
              if (cat != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryExplorerScreen(category: cat)));
              }
            }
          },
        ),
        const SizedBox(height: 15),
        if (section.scroll == 'horizontal')
          Stack(
            children: [
              SizedBox(
                height: section.cardHeight + 130, // Increased to prevent any overflow
                child: ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: section.courses.length,
                  itemBuilder: (context, index) => _buildDynamicCard(context, section, section.courses[index], locale, textColor, isDark),
                ),
              ),
              if (section.courses.length > 1) ...[ // Always show arrows for mouse users
                // Left Arrow
                Positioned(
                  left: 0,
                  top: section.cardHeight / 2 - 20,
                  child: GestureDetector(
                    onTap: () {
                      scrollController.animateTo(scrollController.offset - section.cardWidth, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                      child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    ),
                  ),
                ),
                // Right Arrow
                Positioned(
                  right: 0,
                  top: section.cardHeight / 2 - 20,
                  child: GestureDetector(
                    onTap: () {
                      scrollController.animateTo(scrollController.offset + section.cardWidth, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                      child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ]
            ],
          )
        else if (section.scroll == 'grid')
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: section.cardWidth / (section.cardHeight + 130), // Increased
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: section.courses.length,
            itemBuilder: (context, index) => _buildDynamicCard(context, section, section.courses[index], locale, textColor, isDark),
          )
        else
          ...section.courses.map((CourseModel c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDynamicCard(context, section, c, locale, textColor, isDark),
          )),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildDynamicCard(BuildContext context, SectionModel section, CourseModel course, String locale, Color textColor, bool isDark) {
    final w = section.cardWidth;
    final h = section.cardHeight;
    final isCircle = section.cardShape == 'circle';
    final isSquare = section.cardShape == 'square';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course))),
      child: Container(
        width: w,
        margin: section.scroll == 'horizontal' ? const EdgeInsets.only(right: 14) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with shape
            isCircle
                ? Center(
                    child: ClipOval(
                      child: CourseImage(url: course.coverImageUrl, width: h, height: h),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(isSquare ? 12 : 16),
                    child: CourseImage(url: course.coverImageUrl, width: w, height: h),
                  ),
            const SizedBox(height: 8),
            Text(
              course.getLocalizedTitle(locale),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
            ),
            const SizedBox(height: 4),
            // Category Tag
            if (course.category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentNeon.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  course.category.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.accentNeon),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              course.getLocalizedInstructor(locale),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.5)),
            ),
            const SizedBox(height: 6),
            if (course.price['regular_price'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (course.price['on_sale'] == true)
                    Text("${course.price['regular_price']} ${course.price['currency']}", 
                      style: TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                  Row(
                    children: [
                      Text("${course.price['on_sale'] == true ? course.price['sale_price'] : course.price['regular_price']} ${course.price['currency']}", 
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accentNeon)),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(course.getLocalizedAccessPeriod(locale), 
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.4))),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryExplorerScreen extends StatelessWidget {
  final dynamic category;
  const CategoryExplorerScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final children = category['children'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(category['name'] ?? 'Explore'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.8), Colors.transparent],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark ? [Colors.black, const Color(0xFF121212)] : [Colors.white, const Color(0xFFF0F0F0)],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            if (children.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sub = children[index];
                      return AnimatedHoverCard(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryExplorerScreen(category: sub))),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (sub['icon_image'] != null && sub['icon_image'].toString().isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: sub['icon_image'],
                                  width: 40, height: 40, fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 1, color: AppColors.accentNeon)),
                                  errorWidget: (_, __, ___) => Icon(getCategoryIcon(sub['icon'] ?? sub['slug']), color: AppColors.accentNeon, size: 30),
                                )
                              else
                                Icon(getCategoryIcon(sub['icon'] ?? sub['slug']), color: AppColors.accentNeon, size: 35),
                              const SizedBox(height: 10),
                              Text(sub['name'] ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: children.length,
                  ),
                ),
              ),
            
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Text(
                  AppLocalizations.tr(context, 'courses'),
                  style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            _buildSliverCourseList(context, category['id'] ?? 0, textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverCourseList(BuildContext context, int categoryId, Color textColor) {
    return Consumer<CoursesProvider>(
      builder: (context, provider, child) {
        final courses = provider.courses.where((c) => c.categoryIds.contains(categoryId)).toList();
        
        if (courses.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('No courses found in this category', style: TextStyle(color: Colors.white24))),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final course = courses[index];
                final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: AnimatedHoverCard(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course))),
                    child: GlassContainer(
                      padding: EdgeInsets.zero,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                            child: CourseImage(url: course.coverImageUrl, width: 100, height: 100),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(course.getLocalizedTitle(locale), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 5),
                                Text(course.getLocalizedInstructor(locale), style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 12)),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: AppColors.accentNeon),
                                    const SizedBox(width: 5),
                                    Text('${course.duration} ${AppLocalizations.tr(context, 'hours')}', style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 11)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 16),
                          const SizedBox(width: 15),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: courses.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Colors.white10, thickness: 1),
        const SizedBox(height: 25),
        const Text(
          "© 2026-2027 Jemypedia Platform. All Rights Reserved.\nالحقوق محفوظة لمنصة جيميبيديا 2026/2027",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: () async {
            final url = Uri.parse('https://www.jemypedia.com');
            if (await launchUrl(url)) {}
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.language_rounded, color: AppColors.accentNeon, size: 16),
              SizedBox(width: 8),
              Text(
                "www.jemypedia.com",
                style: TextStyle(
                  color: AppColors.accentNeon,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            InkWell(
              onTap: () async {
                final url = Uri.parse('mailto:Support@Jemypedia.com');
                if (await launchUrl(url)) {}
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.mail_outline_rounded, color: Colors.white30, size: 14),
                  SizedBox(width: 6),
                  Text("Support@Jemypedia.com", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
            InkWell(
              onTap: () async {
                final url = Uri.parse('mailto:Partner@jemypedia.com');
                if (await launchUrl(url)) {}
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.business_center_outlined, color: Colors.white30, size: 14),
                  SizedBox(width: 6),
                  Text("Partner@jemypedia.com", style: TextStyle(color: Colors.white30, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

}

// Top level helper for icons
IconData getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'medical_services':
    case 'medicine':
      return Icons.medical_services_outlined;
    case 'engineering':
      return Icons.engineering_outlined;
    case 'science':
      return Icons.science_outlined;
    case 'trading': 
      return Icons.show_chart_rounded;
    case 'design': 
      return Icons.brush_outlined;
    case 'coding': 
      return Icons.code_rounded;
    case 'business': 
      return Icons.business_center_outlined;
    case 'languages': 
      return Icons.language_rounded;
    case 'biotech':
      return Icons.biotech_outlined;
    case 'computer':
      return Icons.computer_outlined;
    case 'candlestick_chart':
      return Icons.candlestick_chart_rounded;
    case 'school':
      return Icons.school_outlined;
    case 'laptop':
      return Icons.laptop_mac_rounded;
    default: 
      return Icons.folder_open_rounded;
  }
}

class CourseSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final prov = Provider.of<CoursesProvider>(context, listen: false);
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final results = prov.courses.where((c) {
      final tEn = (c.title['en'] ?? '').toString().toLowerCase();
      final tAr = (c.title['ar'] ?? '').toString().toLowerCase();
      final iEn = (c.instructor['en'] ?? '').toString().toLowerCase();
      final iAr = (c.instructor['ar'] ?? '').toString().toLowerCase();
      final q = query.toLowerCase();
      return tEn.contains(q) || tAr.contains(q) || iEn.contains(q) || iAr.contains(q);
    }).toList();

    if (results.isEmpty) return const Center(child: Text("No courses found.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final c = results[index];
        return ListTile(
          contentPadding: const EdgeInsets.all(8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: c.coverImageUrl, 
              width: 60, height: 40, fit: BoxFit.cover, 
              placeholder: (context, url) => Container(color: Colors.white10),
              errorWidget: (_,__,___) => const Icon(Icons.video_library),
            ),
          ),
          title: Text(c.getLocalizedTitle(locale), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(c.getLocalizedInstructor(locale)),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailScreen(course: c)));
          },
        );
      },
    );
  }
}

