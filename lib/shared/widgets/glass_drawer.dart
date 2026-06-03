import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart'; // ThemeProvider + LoginScreen
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/courses/ui/my_courses_screen.dart';
import '../../features/courses/ui/favorites_screen.dart';
import '../../features/courses/ui/watch_later_screen.dart';
import '../../features/certificates/ui/certificates_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../features/support/ui/chat_screen.dart';
import '../../features/home/ui/generic_grid_screen.dart';
import '../../features/home/ui/terms_screen.dart';
import '../../core/services/wordpress_service.dart';
import '../../core/providers/locale_provider.dart';

class GlassDrawer extends StatelessWidget {
  const GlassDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black.withOpacity(0.85) : Colors.white.withOpacity(0.9),
          border: Border(
              right: BorderSide(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1))),
        ),
        child: BackdropFilter(
          filter: ColorFilter.mode(
            (isDark ? Colors.black : Colors.white).withOpacity(0.1),
            BlendMode.overlay,
          ),
          child: Column(
            children: [
              // Header
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.3), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.accentNeon, AppColors.primary],
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          authProvider.isLoggedIn
                              ? (authProvider.displayName ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase()
                              : 'G',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      authProvider.isLoggedIn
                          ? (authProvider.displayName ?? 'User')
                          : 'Guest',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (authProvider.isLoggedIn)
                      Text(
                        authProvider.userEmail ?? '',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    _buildDrawerItem(
                      context, Icons.home_rounded, locale == 'ar' ? 'الرئيسية' : 'Home', true,
                      () => Navigator.pop(context),
                    ),
                    _buildDrawerItem(
                      context, Icons.dashboard_rounded, locale == 'ar' ? 'لوحة التحكم' : 'Dashboard', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const DashboardScreen()));
                      },
                    ),

                    // ─── MY LIBRARY ───────────────────────────────────────
                    _buildSectionLabel(context, locale == 'ar' ? 'مكتبتي' : 'My Library', isDark),

                    _buildDrawerItem(
                      context, Icons.play_lesson_rounded, locale == 'ar' ? 'كورساتي' : 'My Courses', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const MyCoursesScreen()));
                      },
                    ),
                    _buildDrawerItem(
                      context, Icons.favorite_rounded, locale == 'ar' ? 'المفضلة' : 'My Favorites', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                      },
                      iconColor: Colors.redAccent,
                    ),
                    _buildDrawerItem(
                      context, Icons.bookmark_rounded, locale == 'ar' ? 'المشاهدة لاحقاً' : 'Watch Later', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const WatchLaterScreen()));
                      },
                      iconColor: Colors.orangeAccent,
                    ),
                    _buildDrawerItem(
                      context, Icons.card_membership_rounded, locale == 'ar' ? 'شهاداتي' : 'My Certificates', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const CertificatesScreen()));
                      },
                    ),

                    // ─── ABOUT ACADEMY ────────────────────────────────────
                    _buildSectionLabel(context, locale == 'ar' ? 'عن الأكاديمية' : 'About Academy', isDark),

                    _buildDrawerItem(
                      context, Icons.school_rounded, locale == 'ar' ? 'فريق العمل' : 'Our Team', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => GenericGridScreen(
                              titleAr: 'فريق العمل', 
                              titleEn: 'Our Team',
                              fetchData: () => WordPressService().getInstructors(),
                            )));
                      },
                    ),
                    _buildDrawerItem(
                      context, Icons.handshake_rounded, locale == 'ar' ? 'شركاؤنا وداعمينا' : 'Partners & Sponsors', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => GenericGridScreen(
                              titleAr: 'شركاؤنا وداعمينا', 
                              titleEn: 'Partners & Sponsors',
                              fetchData: () => WordPressService().getPartners(),
                            )));
                      },
                    ),
                    _buildDrawerItem(
                      context, Icons.gavel_rounded, locale == 'ar' ? 'الشروط والأحكام' : 'Terms & Conditions', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const TermsScreen()));
                      },
                    ),

                    // ─── SUPPORT ──────────────────────────────────────────
                    _buildSectionLabel(context, locale == 'ar' ? 'الدعم الفني' : 'Support', isDark),

                    _buildDrawerItem(
                      context, Icons.support_agent_rounded, locale == 'ar' ? 'المساعد الذكي' : 'AI Assistant', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ChatScreen()));
                      },
                    ),
                    _buildDrawerItem(
                      context, Icons.settings_rounded, locale == 'ar' ? 'الإعدادات' : 'Settings', false,
                      () {
                        Navigator.pop(context);
                        Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()));
                      },
                    ),

                    _buildThemeToggle(context, themeProvider),
                  ],
                ),
              ),

              // Logout / Login
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDrawerItem(
                  context,
                  authProvider.isLoggedIn ? Icons.logout_rounded : Icons.login_rounded,
                  authProvider.isLoggedIn 
                      ? (locale == 'ar' ? 'تسجيل الخروج' : 'Logout') 
                      : (locale == 'ar' ? 'تسجيل الدخول' : 'Login'),
                  false,
                  () {
                    Navigator.pop(context);
                    if (authProvider.isLoggedIn) {
                      authProvider.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    } else {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()));
                    }
                  },
                  isLogout: authProvider.isLoggedIn,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white30 : Colors.black38,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String title,
    bool isActive,
    VoidCallback onTap, {
    bool isLogout = false,
    Color? iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : Colors.black;
    final color = isLogout
        ? Colors.redAccent
        : (isActive ? AppColors.primary : (iconColor ?? defaultColor.withOpacity(0.7)));

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isLogout
                ? Colors.redAccent
                : (isActive ? AppColors.primary : defaultColor),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        onTap: onTap,
        dense: true,
      ),
    );
  }

  Widget _buildThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    final isDark = themeProvider.isDarkMode;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.accentNeon.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          color: isDark ? Colors.orangeAccent : Colors.indigo,
        ),
        title: Text(
          isDark 
            ? (Provider.of<LocaleProvider>(context).locale.languageCode == 'ar' ? 'الوضع الفاتح' : 'Light Mode')
            : (Provider.of<LocaleProvider>(context).locale.languageCode == 'ar' ? 'الوضع الداكن' : 'Dark Mode'),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        trailing: Switch(
          value: isDark,
          onChanged: (_) => themeProvider.toggleTheme(),
          activeColor: AppColors.accentNeon,
        ),
        onTap: () => themeProvider.toggleTheme(),
      ),
    );
  }
}
