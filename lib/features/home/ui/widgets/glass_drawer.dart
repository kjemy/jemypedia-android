import 'package:flutter/material.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dashboard/ui/dashboard_screen.dart';
import '../../../courses/ui/my_courses_screen.dart';
import '../../../certificates/ui/certificates_screen.dart';
import '../../../subscriptions/ui/subscription_screen.dart';
import '../../../settings/ui/settings_screen.dart';
import '../../../../core/localization/app_localizations.dart';

class GlassDrawer extends StatelessWidget {
  const GlassDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: GlassContainer(
        borderRadius: 0,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Consumer<AuthProvider>(
              builder: (context, auth, _) => UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                accountName: Text(auth.displayName ?? 'Jemy Student', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                accountEmail: Text(auth.userEmail ?? 'student@jemyacademy.com', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 40),
                ),
              ),
            ),
            const Divider(color: Colors.white24),
            _buildDrawerItem(context, Icons.dashboard, AppLocalizations.tr(context, 'dashboard'), isDark, const DashboardScreen()),
            _buildDrawerItem(context, Icons.play_lesson, AppLocalizations.tr(context, 'my_courses'), isDark, const MyCoursesScreen()),
            _buildDrawerItem(context, Icons.workspace_premium, AppLocalizations.tr(context, 'certificates'), isDark, const CertificatesScreen()),
            _buildDrawerItem(context, Icons.monetization_on, AppLocalizations.tr(context, 'subscriptions'), isDark, const SubscriptionScreen()),
            const Divider(color: Colors.white24),
            _buildDrawerItem(context, Icons.settings, AppLocalizations.tr(context, 'settings'), isDark, const SettingsScreen()),
            _buildDrawerItem(context, Icons.logout, AppLocalizations.tr(context, 'logout'), isDark, null, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, bool isDark, Widget? destination, {Color? color}) {
    final defaultColor = isDark ? Colors.white : Colors.black87;
    return ListTile(
      leading: Icon(icon, color: color ?? defaultColor),
      title: Text(title, style: TextStyle(color: color ?? defaultColor, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context); // Close the drawer
        if (destination != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          );
        } else {
          // Mock logout
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging out...')));
        }
      },
    );
  }
}
