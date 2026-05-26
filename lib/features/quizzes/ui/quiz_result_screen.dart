import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/quiz_model.dart';

class QuizResultScreen extends StatelessWidget {
  final QuizResultModel result;
  final QuizModel quiz;

  const QuizResultScreen({super.key, required this.result, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final passed = result.passed;

    final gradeColor = result.score >= 90
        ? Colors.amber
        : result.score >= 80
            ? Colors.green
            : result.score >= 70
                ? Colors.blue
                : Colors.redAccent;

    final emoji = result.score >= 90
        ? '🏆'
        : result.score >= 80
            ? '🎉'
            : result.score >= 70
                ? '👍'
                : '😔';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF5F5FF),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(locale == 'ar' ? 'نتيجة الاختبار' : 'Quiz Result',
            style: const TextStyle(color: Colors.white)),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Score Circle
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: passed
                        ? [AppColors.accentNeon, AppColors.primary]
                        : [Colors.redAccent, Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [BoxShadow(color: (passed ? AppColors.accentNeon : Colors.redAccent).withOpacity(0.4), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 36)),
                      Text('${result.score}%',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Grade Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: gradeColor, width: 2),
                ),
                child: Text(
                  result.getLocalizedGrade(locale),
                  style: TextStyle(color: gradeColor, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                passed
                    ? (locale == 'ar' ? '🎊 لقد اجتزت الاختبار بنجاح!' : '🎊 You passed the quiz!')
                    : (locale == 'ar' ? 'لم تجتز الاختبار هذه المرة' : 'You did not pass this time'),
                style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Stats
              GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatRow(locale == 'ar' ? 'الإجابات الصحيحة' : 'Correct Answers',
                        '${result.correct} / ${result.total}', Colors.green, context),
                    const Divider(height: 20),
                    _buildStatRow(locale == 'ar' ? 'درجة النجاح المطلوبة' : 'Required Pass Score',
                        '${result.passScore}%', AppColors.primary, context),
                    const Divider(height: 20),
                    _buildStatRow(locale == 'ar' ? 'درجتك' : 'Your Score',
                        '${result.score}%', gradeColor, context),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              if (!passed) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(locale == 'ar' ? 'إعادة المحاولة' : 'Try Again'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton.icon(
                onPressed: () {
                  int count = 0;
                  Navigator.popUntil(context, (_) => count++ >= 2);
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                label: Text(locale == 'ar' ? 'العودة للكورس' : 'Back to Course',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}
