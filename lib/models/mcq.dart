class MCQ {
   int? id;
  final String course;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String answer;
  String? userId;
  int? questionNumber;
  int isDeleted;

   MCQ({
    this.id,
    required this.course,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.answer,
    this.userId,
    this.questionNumber,
     this.isDeleted = 0,
  });

  /// 🔹 From SQLite / Firestore map
  factory MCQ.fromMap(Map<String, dynamic> map) {
    return MCQ(
      id: map['id'] as int?,
      course: (map['course'] ?? '') as String,
      question: (map['question'] ?? '') as String,
      optionA: (map['option_A'] ?? '') as String,
      optionB: (map['option_B'] ?? '') as String,
      optionC: (map['option_C'] ?? '') as String,
      optionD: (map['option_D'] ?? '') as String,
      answer: (map['answer'] ?? '') as String,
      userId: map['userId'] as String?,
      questionNumber: map['questionNumber'] is int
          ? map['questionNumber'] as int
          : (map['questionNumber'] != null
          ? int.tryParse(map['questionNumber'].toString())
          : null),
      isDeleted: map['isDeleted'] is int
          ? map['isDeleted'] as int
          : (map['isDeleted'] == true ? 1 : 0),
    );
  }

  /// 🔹 To SQLite / Firestore map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'course': course,
      'question': question,
      'option_A': optionA,
      'option_B': optionB,
      'option_C': optionC,
      'option_D': optionD,
      'answer': answer,
      'isDeleted': isDeleted,
    };
    if (id != null) map['id'] = id;
    if (userId != null) map['userId'] = userId;
    if (questionNumber != null) map['questionNumber'] = questionNumber;
    return map;
  }

  /// 🔹 CopyWith for immutability
  MCQ copyWith({
    int? id,
    String? course,
    String? question,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? answer,
    String? userId,
    int? questionNumber,
    int? isDeleted,
  }) {
    return MCQ(
      id: id ?? this.id,
      course: course ?? this.course,
      question: question ?? this.question,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      answer: answer ?? this.answer,
      userId: userId ?? this.userId,
      questionNumber: questionNumber ?? this.questionNumber,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
