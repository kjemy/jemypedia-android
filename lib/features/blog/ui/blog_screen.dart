import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jemypedia_app/core/providers/articles_provider.dart';
import 'package:jemypedia_app/core/providers/locale_provider.dart';
import 'package:jemypedia_app/features/articles/ui/article_detail_screen.dart';
import 'package:jemypedia_app/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticlesProvider>(context, listen: false).fetchArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleProvider>().isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'المدونة' : 'Blog'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Consumer<ArticlesProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.articles.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            
            return Column(
              children: [
                // Categories
                if (provider.categories.isNotEmpty)
                  Container(
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.categories.length + 1,
                      itemBuilder: (context, index) {
                        final isAll = index == 0;
                        final isSelected = isAll ? provider.selectedCategoryId == 0 : provider.selectedCategoryId == provider.categories[index - 1].id;
                        final title = isAll ? (isArabic ? 'الكل' : 'All') : provider.categories[index - 1].name;
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0, left: 8.0),
                          child: ChoiceChip(
                            label: Text(title),
                            selected: isSelected,
                            onSelected: (selected) {
                              provider.selectCategory(isAll ? 0 : provider.categories[index - 1].id);
                            },
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                          ),
                        );
                      },
                    ),
                  ),
                  
                // Articles List
                Expanded(
                  child: provider.articles.isEmpty
                      ? Center(child: Text(isArabic ? 'لا توجد مقالات.' : 'No articles found.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.articles.length,
                          itemBuilder: (context, index) {
                            final article = provider.articles[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ArticleDetailScreen(article: article),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                                      child: CachedNetworkImage(
                                        imageUrl: article.imageUrl,
                                        height: 200,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(color: Colors.grey.shade300),
                                        errorWidget: (context, url, error) => Container(
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            article.getLocalizedTitle(isArabic ? 'ar' : 'en').replaceAll(RegExp(r'<[^>]*>'), ''),
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            article.getLocalizedContent(isArabic ? 'ar' : 'en').replaceAll(RegExp(r'<[^>]*>'), ''),
                                            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14, height: 1.5),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                article.date.split('T').first,
                                                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                              ),
                                              Text(
                                                isArabic ? 'اقرأ المزيد' : 'Read More',
                                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
