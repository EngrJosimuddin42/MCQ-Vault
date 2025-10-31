import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<pw.Document> generate({
    required String selectedCourse,
    required List<dynamic> filteredQuestions,
  }) async {
    final pdf = pw.Document();
    final margin = pw.EdgeInsets.all(72);

    // Question Paper Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: margin,
        header: (context) {
          if (context.pageNumber == 1) {
            final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());
            final totalMarks = filteredQuestions.length;
            final totalTime = '${filteredQuestions.length} min';
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('MCQ Paper - $selectedCourse',
                        style: pw.TextStyle(
                            fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Generated on: $formattedDate',
                        style: pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text('Marks: $totalMarks    Time: $totalTime',
                        style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                            fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.Divider(thickness: 1),
                ),
                pw.SizedBox(height: 10),
              ],
            );
          }
          return pw.SizedBox();
        },
        build: (context) {
          pw.Widget questionWidget(int number, dynamic q) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('$number. ${q.question}',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 10),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                              child: pw.Text('A) ${q.optionA}',
                                  style: pw.TextStyle(fontSize: 12))),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                              child: pw.Text('B) ${q.optionB}',
                                  style: pw.TextStyle(fontSize: 12))),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Expanded(
                              child: pw.Text('C) ${q.optionC}',
                                  style: pw.TextStyle(fontSize: 12))),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                              child: pw.Text('D) ${q.optionD}',
                                  style: pw.TextStyle(fontSize: 12))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          List<pw.Widget> content = [];
          int questionNumber = 1;

          for (int i = 0; i < filteredQuestions.length; i += 2) {
            pw.Widget left = questionWidget(questionNumber, filteredQuestions[i]);
            questionNumber++;

            pw.Widget right = pw.Container();
            if (i + 1 < filteredQuestions.length) {
              right = questionWidget(questionNumber, filteredQuestions[i + 1]);
              questionNumber++;
            }

            content.add(
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: left),
                  pw.SizedBox(width: 20),
                  pw.Expanded(child: right),
                ],
              ),
            );
            content.add(pw.SizedBox(height: 14));
          }

          return content;
        },
      ),
    );

    // Answer Key Page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: margin,
        build: (context) {
          final half = (filteredQuestions.length / 2).ceil();
          final leftColumn = filteredQuestions.sublist(0, half);
          final rightColumn = filteredQuestions.sublist(half);
          final formattedDate = DateFormat('dd-MM-yyyy').format(DateTime.now());

          String getAnswerText(q) {
            switch (q.answer.toUpperCase()) {
              case 'A':
                return 'A) ${q.optionA}';
              case 'B':
                return 'B) ${q.optionB}';
              case 'C':
                return 'C) ${q.optionC}';
              case 'D':
                return 'D) ${q.optionD}';
              default:
                return q.answer;
            }
          }

          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Answer Key - $selectedCourse',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text('Generated on: $formattedDate',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              ],
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              child: pw.Divider(thickness: 1),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: List.generate(leftColumn.length, (i) {
                      final q = leftColumn[i];
                      final answerText = getAnswerText(q);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text('${i + 1}.  $answerText',
                            style: pw.TextStyle(fontSize: 14)),
                      );
                    }),
                  ),
                ),
                pw.SizedBox(width: 40),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: List.generate(rightColumn.length, (i) {
                      final q = rightColumn[i];
                      final index = i + leftColumn.length;
                      final answerText = getAnswerText(q);
                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text('${index + 1}.  $answerText',
                            style: pw.TextStyle(fontSize: 14)),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }
}
