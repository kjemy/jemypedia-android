import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../core/services/wordpress_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_container.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final WordPressService _wpService = WordPressService();
  bool _isLoading = true;
  String _termsText = '';

  @override
  void initState() {
    super.initState();
    _fetchTerms();
  }

  Future<void> _fetchTerms() async {
    final terms = await _wpService.getTerms();
    // Use Arabic terms by default, fallback to English if empty
    String content = terms['ar']?.isNotEmpty == true ? terms['ar']! : terms['en'] ?? 'No Terms Available';
    
    if (mounted) {
      setState(() {
        _termsText = content;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الشروط والأحكام'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentNeon))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Html(
                  data: _termsText,
                  style: {
                    "body": Style(
                      color: textColor,
                      fontSize: FontSize(16.0),
                      lineHeight: const LineHeight(1.6),
                      textAlign: TextAlign.right, // RTL for Arabic
                    ),
                    "h1": Style(color: AppColors.accentNeon),
                    "h2": Style(color: AppColors.primary),
                    "a": Style(color: Colors.blueAccent, textDecoration: TextDecoration.none),
                  },
                ),
              ),
            ),
    );
  }
}
