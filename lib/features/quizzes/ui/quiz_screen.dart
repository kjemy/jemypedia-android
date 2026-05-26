import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/glass_container.dart';
import '../models/quiz_model.dart';
import 'quiz_result_screen.dart';
import 'package:provider/provider.dart';

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  final VoidCallback? onPassed;

  const QuizScreen({super.key, required this.quiz, this.onPassed});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentIndex = 0;
  final Map<int, dynamic> _answers = {};
  final TextEditingController _fillController = TextEditingController();
  bool _submitting = false;

  QuestionModel get _current => widget.quiz.questions[_currentIndex];
  bool get _isLast => _currentIndex == widget.quiz.questions.length - 1;

  void _selectChoice(int choiceIndex) {
    setState(() => _answers[_currentIndex] = choiceIndex);
  }

  void _next() {
    if (_currentIndex < widget.quiz.questions.length - 1) {
      setState(() {
        if (_current.type == 'fill_blank') {
          _answers[_currentIndex] = _fillController.text;
          _fillController.clear();
        }
        _currentIndex++;
        if (_current.type == 'fill_blank') {
          _fillController.text = _answers[_currentIndex]?.toString() ?? '';
        }
      });
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      setState(() {
        if (_current.type == 'fill_blank') {
          _answers[_currentIndex] = _fillController.text;
          _fillController.clear();
        }
        _currentIndex--;
        if (_current.type == 'fill_blank') {
          _fillController.text = _answers[_currentIndex]?.toString() ?? '';
        }
      });
    }
  }

  Future<void> _submit() async {
    final locale = Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    if (_current.type == 'fill_blank') {
      _answers[_currentIndex] = _fillController.text;
    }

    setState(() => _submitting = true);

    final baseUrl = 'https://www.jemypedia.com/wp-json/jemy-academy/v1';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final answersMap = <String, dynamic>{};
    _answers.forEach((k, v) => answersMap[k.toString()] = v);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quiz/${widget.quiz.id}/submit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'answers': answersMap,
          'email': auth.userEmail ?? '',
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted && response.statusCode == 200) {
        final result = QuizResultModel.fromJson(jsonDecode(response.body));
        setState(() => _submitting = false);
        if (result.passed) widget.onPassed?.call();
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => QuizResultScreen(result: result, quiz: widget.quiz),
        ));
      }
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(locale == 'ar' ? 'فشل الاتصال، حاول مرة أخرى.' : 'Connection failed, please try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Provider.of<LocaleProvider>(context).locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final total = widget.quiz.questions.length;
    final q = _current;
    final selectedAnswer = _answers[_currentIndex];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D1A) : const Color(0xFFF5F5FF),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(widget.quiz.getLocalizedTitle(locale), style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Progress
          Container(
            color: AppColors.primary.withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(locale == 'ar' ? 'السؤال ${_currentIndex + 1} من $total' : 'Question ${_currentIndex + 1} of $total',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                    Text('${((_currentIndex + 1) / total * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.accentNeon, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / total,
                    backgroundColor: Colors.white10,
                    color: AppColors.accentNeon,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Question Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Media: image or video
                  if (q.imageUrl.isNotEmpty && (q.type == 'image_mcq'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(q.imageUrl, fit: BoxFit.cover, width: double.infinity, height: 200),
                    ),
                  if (q.videoUrl.isNotEmpty && (q.type == 'video_mcq')) ...[
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill, color: AppColors.accentNeon, size: 40),
                          const SizedBox(width: 12),
                          Expanded(child: Text(locale == 'ar' ? 'شاهد الفيديو أولاً ثم أجب على السؤال' : 'Watch the video first, then answer', style: TextStyle(color: textColor))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 16),
                  // Question Text
                  GlassContainer(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      q.getLocalizedText(locale),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textColor, height: 1.5),
                      textAlign: locale == 'ar' ? TextAlign.right : TextAlign.left,
                      textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Choices / Input
                  if (q.type == 'fill_blank') ...[
                    TextField(
                      controller: _fillController,
                      textAlign: locale == 'ar' ? TextAlign.right : TextAlign.left,
                      textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
                      decoration: InputDecoration(
                        hintText: locale == 'ar' ? 'اكتب إجابتك هنا...' : 'Type your answer here...',
                        filled: true,
                        fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: AppColors.accentNeon, width: 2),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                  ] else ...[
                    ...List.generate(
                      q.type == 'true_false' ? 2 : q.choices.length,
                      (i) {
                        final label = q.type == 'true_false'
                            ? (i == 0 ? (locale == 'ar' ? '✓  صحيح' : '✓  True') : (locale == 'ar' ? '✗  خطأ' : '✗  False'))
                            : (i < q.choices.length ? q.choices[i] : '');
                        if (label.isEmpty) return const SizedBox.shrink();
                        final isSelected = selectedAnswer == i;
                        return GestureDetector(
                          onTap: () => _selectChoice(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accentNeon.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected ? AppColors.accentNeon : Colors.grey.withOpacity(0.3),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? AppColors.accentNeon : Colors.transparent,
                                    border: Border.all(color: isSelected ? AppColors.accentNeon : Colors.grey, width: 2),
                                  ),
                                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Text(label, style: TextStyle(color: textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black54 : Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previous,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(locale == 'ar' ? 'السابق' : 'Previous', style: const TextStyle(color: AppColors.primary)),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : (_isLast ? _submit : _next),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLast ? Colors.red : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _submitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _isLast ? (locale == 'ar' ? 'تسليم الإجابات' : 'Submit') : (locale == 'ar' ? 'التالي ←' : 'Next →'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
