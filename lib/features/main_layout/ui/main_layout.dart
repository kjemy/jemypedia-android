import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:jemypedia_app/features/home/ui/home_screen.dart';
import 'package:jemypedia_app/features/flash/providers/flash_provider.dart';
import 'package:jemypedia_app/features/flash/ui/flash_screen.dart';
import 'package:jemypedia_app/features/blog/ui/blog_screen.dart';
import 'package:jemypedia_app/features/dashboard/ui/dashboard_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FlashScreen(),
    const BlogScreen(),
    const DashboardScreen(), // This acts as the Profile tab now
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FlashProvider>(context, listen: false).fetchFlashItems(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = context.watch<LocaleProvider>().isArabic;
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? Colors.black : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: isArabic ? 'الرئيسية' : 'Home',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.flash_on_outlined),
            activeIcon: const Icon(Icons.flash_on),
            label: 'Flash',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.article_outlined),
            activeIcon: const Icon(Icons.article),
            label: isArabic ? 'المدونة' : 'Blog',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: isArabic ? 'حسابي' : 'Account',
          ),
        ],
      ),
    );
  }
}
