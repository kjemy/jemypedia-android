import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/localization/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.tr(context, 'settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GlassContainer(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Consumer2<ThemeProvider, LocaleProvider>(
                  builder: (context, themeProvider, localeProvider, child) {
                    return Column(
                      children: [
                        SwitchListTile(
                          title: Text(AppLocalizations.tr(context, 'dark_mode'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          subtitle: Text(AppLocalizations.tr(context, 'toggle_theme'), style: TextStyle(color: textColor.withOpacity(0.7))),
                          value: themeProvider.isDarkMode,
                          activeColor: AppColors.accentNeon,
                          onChanged: (bool value) {
                            themeProvider.toggleTheme();
                          },
                        ),
                        const Divider(height: 1, color: Colors.white24),
                        ListTile(
                          title: Text(AppLocalizations.tr(context, 'language'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          subtitle: Text(AppLocalizations.tr(context, 'current_language'), style: TextStyle(color: textColor.withOpacity(0.7))),
                          trailing: const Icon(Icons.language, size: 20, color: Colors.grey),
                          onTap: () {
                            localeProvider.toggleLocale();
                          },
                        ),
                      ],
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white24),
                ListTile(
                  title: Text(AppLocalizations.tr(context, 'account_details'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppColors.bgDark,
                        title: Text(AppLocalizations.tr(context, 'account_details'), style: const TextStyle(color: Colors.white)),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Name: Student User', style: TextStyle(color: Colors.white70)),
                            Text('Email: student@jemyacademy.com', style: TextStyle(color: Colors.white70)),
                            Text('Phone: +20123456789', style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          )
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1, color: Colors.white24),
                ListTile(
                  title: Text(AppLocalizations.tr(context, 'logout'), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  onTap: () {},
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
