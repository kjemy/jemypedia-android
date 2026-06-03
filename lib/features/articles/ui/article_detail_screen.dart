import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../models/article_model.dart';
import '../../../shared/widgets/glass_container.dart';

class ArticleDetailScreen extends StatelessWidget {
  final ArticleModel article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
            iconTheme: IconThemeData(color: textColor),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                article.imageUrl,
                fit: BoxFit.cover,
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
                    article.getLocalizedTitle(locale),
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
                          article.author.isNotEmpty ? article.author[0] : 'A',
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${article.author} • ${article.date}',
                        style: TextStyle(color: textColor.withOpacity(0.6)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        article.getLocalizedContent(locale),
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          color: textColor.withOpacity(0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
