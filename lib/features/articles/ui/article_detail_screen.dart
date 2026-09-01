import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../models/article_model.dart';

class ArticleDetailScreen extends StatelessWidget {
  final ArticleModel article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isArabic = locale == 'ar';
    final authorName = article.getLocalizedAuthor(locale);

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
              iconTheme: IconThemeData(color: textColor),
              flexibleSpace: FlexibleSpaceBar(
                background: CachedNetworkImage(
                  imageUrl: article.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey.shade300),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.getLocalizedTitle(locale).replaceAll(RegExp(r'<[^>]*>'), ''), // Remove basic html tags from title just in case
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.accentNeon,
                          child: Text(
                            authorName.isNotEmpty ? authorName[0] : 'A',
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$authorName • ${article.date.split('T').first}',
                          style: TextStyle(color: textColor.withOpacity(0.6)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Html(
                      data: article.getLocalizedFullContent(locale),
                      style: {
                        "body": Style(
                          fontSize: FontSize(18.0),
                          color: textColor,
                          lineHeight: LineHeight(1.6),
                        ),
                        "p": Style(margin: Margins.only(bottom: 10.0)),
                        "h1": Style(color: AppColors.primary),
                        "h2": Style(color: AppColors.primary),
                        "h3": Style(color: AppColors.primary),
                        "a": Style(color: AppColors.accentBlue, textDecoration: TextDecoration.none),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
