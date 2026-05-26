import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/wordpress_service.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final WordPressService _api = WordPressService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.getTerms();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'ar' ? 'الشروط والأحكام' : 'Terms & Conditions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.accentNeon));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(locale == 'ar' ? 'فشل تحميل البيانات' : 'Failed to load data', style: TextStyle(color: textColor)));
          }

          final terms = snapshot.data![locale] ?? '';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Text(
                terms.isEmpty ? (locale == 'ar' ? 'لا يوجد نصوص حالياً' : 'No terms available') : terms,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.6),
              ),
            ),
          );
        },
      ),
    );
  }
}
