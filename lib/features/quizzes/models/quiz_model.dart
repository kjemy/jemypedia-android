class QuizModel {
  final int id;
  final String titleAr;
  final String titleEn;
  final String type; // before_course | after_lesson | after_course | free_level
  final int passScore;
  final int lessonId;
  final int courseId;
  final bool certRequired;
  final bool isFree;
  final List<QuestionModel> questions;

  QuizModel({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.type,
    required this.passScore,
    required this.lessonId,
    required this.courseId,
    required this.certRequired,
    this.isFree = false,
    required this.questions,
  });

  String getLocalizedTitle(String locale) => locale == 'ar' ? titleAr : titleEn;

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id:           json['id'] ?? 0,
      titleAr:      json['title_ar'] ?? '',
      titleEn:      json['title_en'] ?? '',
      type:         json['type'] ?? 'after_course',
      passScore:    json['pass_score'] ?? 70,
      lessonId:     json['lesson_id'] ?? 0,
      courseId:     json['course_id'] ?? 0,
      certRequired: json['cert_required'] ?? false,
      isFree:       json['is_free'] ?? false,
      questions:    (json['questions'] as List? ?? [])
                        .map((q) => QuestionModel.fromJson(q))
                        .toList(),
    );
  }
}

class QuestionModel {
  final int id;
  final String type; // mcq | true_false | fill_blank | image_mcq | video_mcq
  final String textAr;
  final String textEn;
  final String imageUrl;
  final String videoUrl;
  final List<String> choices;
  final int correctIndex;
  final String fillAnswer;

  QuestionModel({
    required this.id,
    required this.type,
    required this.textAr,
    required this.textEn,
    required this.imageUrl,
    required this.videoUrl,
    required this.choices,
    required this.correctIndex,
    required this.fillAnswer,
  });

  String getLocalizedText(String locale) => locale == 'ar' ? textAr : textEn;

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id:           json['id'] ?? 0,
      type:         json['type'] ?? 'mcq',
      textAr:       json['text_ar'] ?? '',
      textEn:       json['text_en'] ?? '',
      imageUrl:     json['image_url'] ?? '',
      videoUrl:     json['video_url'] ?? '',
      choices:      List<String>.from(json['choices'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
      fillAnswer:   json['fill_answer'] ?? '',
    );
  }
}

class QuizResultModel {
  final int score;
  final int correct;
  final int total;
  final bool passed;
  final Map<String, String> grade; // {'ar': '...', 'en': '...'}
  final int passScore;

  QuizResultModel({
    required this.score,
    required this.correct,
    required this.total,
    required this.passed,
    required this.grade,
    required this.passScore,
  });

  String getLocalizedGrade(String locale) => grade[locale] ?? grade['en'] ?? '';

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      score:     json['score'] ?? 0,
      correct:   json['correct'] ?? 0,
      total:     json['total'] ?? 0,
      passed:    json['passed'] ?? false,
      grade:     Map<String, String>.from(json['grade'] ?? {}),
      passScore: json['pass_score'] ?? 70,
    );
  }
}
