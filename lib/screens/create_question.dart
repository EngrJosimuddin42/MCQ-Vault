import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import '../db/db_helper.dart';
import '../services/custom_snackbar.dart';
import '../services/pdf_generator.dart';

class CreateQuestionScreen extends StatefulWidget {
  const CreateQuestionScreen({super.key});

  @override
  State<CreateQuestionScreen> createState() => _CreateQuestionScreenState();
}

class _CreateQuestionScreenState extends State<CreateQuestionScreen> {
  String? selectedCourse;
  List<String> courses = [];
  final TextEditingController numController = TextEditingController();
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController customController = TextEditingController();
  String? oddEvenSelection;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final all = await DBHelper().getAllQuestions();
    final uniqueCourses = all.map((e) => e.course).toSet().toList();
    setState(() {
      courses = uniqueCourses;
      if (uniqueCourses.length == 1) {
        selectedCourse = uniqueCourses.first;
      }
    });
  }

  Future<List<Map<String, dynamic>>> _getCourseWiseCount() async {
    return await DBHelper().getCourseWiseMCQCount();
  }

  Future<void> _showCourseCountDialog() async {
    final data = await _getCourseWiseCount();
    if (!mounted) return;
    if (data.isEmpty) {
      CustomSnackbar.show(
        context,
        "⚠️ No data found in database!",
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("📊 MCQs per Course"),
        content: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.blue.shade100),
            columns: const [
              DataColumn(label: Text('Course')),
              DataColumn(label: Text('MCQs')),
            ],
            rows: data
                .map((row) => DataRow(cells: [
              DataCell(Text(row['course'].toString())),
              DataCell(Text(row['count'].toString())),
            ]))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePDF() async {
    if (selectedCourse == null || numController.text.isEmpty) {
      CustomSnackbar.show(
        context,
        "⚠️ Please select course and number!",
        backgroundColor: Colors.red,
      );
      return;
    }

    final allQuestions =
    await DBHelper().getQuestionsByCourse(selectedCourse!, limit: null);

    if (allQuestions.isEmpty) {
      if (!mounted) return;
      CustomSnackbar.show(
        context,
        "❌ No questions found for this course",
        backgroundColor: Colors.redAccent,
      );
      return;
    }

    // 🔹 Filtering logic (unchanged)
    List<int> customNumbers = [];
    if (customController.text.isNotEmpty) {
      final parts = customController.text.split(',');
      for (var part in parts) {
        part = part.trim();
        if (part.isEmpty) continue;

        final rangeMatch = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(part);
        if (rangeMatch != null) {
          int start = int.parse(rangeMatch.group(1)!);
          int end = int.parse(rangeMatch.group(2)!);
          if (start > end) {
            final temp = start;
            start = end;
            end = temp;
          }
          for (int i = start; i <= end; i++) {
            customNumbers.add(i);
          }
        } else if (RegExp(r'^\d+$').hasMatch(part)) {
          customNumbers.add(int.parse(part));
        }
      }
    }

    int startNumber = int.tryParse(startController.text) ?? 1;
    int endNumber = int.tryParse(endController.text) ?? allQuestions.length;
    bool oddNumbersOnly = oddEvenSelection == "Odd";
    bool evenNumbersOnly = oddEvenSelection == "Even";

    List<dynamic> filteredQuestions = [];

    for (final q in allQuestions) {
      final qNumber = q.questionNumber ?? 0;

      if (customNumbers.isNotEmpty) {
        if (!customNumbers.contains(qNumber)) continue;
      } else if (startController.text.isNotEmpty ||
          endController.text.isNotEmpty ||
          oddNumbersOnly ||
          evenNumbersOnly) {
        if (qNumber < startNumber || qNumber > endNumber) continue;
        if (oddNumbersOnly && qNumber % 2 == 0) continue;
        if (evenNumbersOnly && qNumber % 2 != 0) continue;
      }
      filteredQuestions.add(q);
    }

    int totalQ = int.tryParse(numController.text) ?? filteredQuestions.length;

    if (customNumbers.isEmpty &&
        startController.text.isEmpty &&
        endController.text.isEmpty &&
        !oddNumbersOnly &&
        !evenNumbersOnly) {
      filteredQuestions = allQuestions.take(totalQ).toList();
    } else if (filteredQuestions.length > totalQ) {
      filteredQuestions = filteredQuestions.sublist(0, totalQ);
    }

    if (filteredQuestions.isEmpty) {
      if (!mounted) return;
      CustomSnackbar.show(
        context,
        "⚠️ No questions found after applying filters!",
        backgroundColor: Colors.orange,
      );
      return;
    }

    // 🔹 আলাদা ফাইল থেকে PDF তৈরি
    final pdf = await PdfGenerator.generate(
      selectedCourse: selectedCourse!,
      filteredQuestions: filteredQuestions,
    );

    // 🧾 Preview দেখানো
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreview(
          build: (format) => pdf.save(),
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: "MCQ_${selectedCourse!}.pdf",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("📘 Create Question"),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Generate MCQ Paper",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 400,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    isExpanded: true,
                    value: selectedCourse,
                    hint: const Text("Select Course"),
                    items: courses
                        .map((course) => DropdownMenuItem<String>(
                      value: course,
                      child: Text(course),
                    ))
                        .toList(),
                    onChanged: (val) => setState(() => selectedCourse = val),
                    dropdownStyleData: DropdownStyleData(
                      width: 190,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.black26,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      offset: const Offset(200, 0),
                      elevation: 4,
                    ),
                    buttonStyleData: ButtonStyleData(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                        color: Colors.white,
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
                      iconSize: 30,
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                        padding: EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: numController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Number of Questions",
                prefixIcon: const Icon(Icons.format_list_numbered),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: startController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Start Number",
                prefixIcon: const Icon(Icons.play_arrow),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: endController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "End Number",
                prefixIcon: const Icon(Icons.stop),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: customController,
              decoration: InputDecoration(
                labelText:
                "Custom Question Numbers (e.g. 1,3,5-7,11,12,25-30)",
                prefixIcon: const Icon(Icons.numbers),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 400,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    isExpanded: true,
                    value: oddEvenSelection,
                    hint: const Text("Select Odd / Even / None"),
                    items: ["Odd", "Even", "None"]
                        .map((e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e),
                    ))
                        .toList(),
                    onChanged: (val) => setState(() => oddEvenSelection = val),
                    dropdownStyleData: DropdownStyleData(
                      width: 190,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white,
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4,
                            color: Colors.black26,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      offset: const Offset(200, 0),
                      elevation: 4,
                    ),
                    buttonStyleData: ButtonStyleData(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade400),
                        color: Colors.white,
                      ),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(Icons.arrow_drop_down, color: Colors.indigo),
                      iconSize: 30,
                    ),
                    menuItemStyleData: const MenuItemStyleData(
                        padding: EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),

            Expanded(
              child: GridView.count(
                crossAxisCount: 1,
                childAspectRatio: 3,
                mainAxisSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 26),
                    label: const Text("Generate PDF",
                        style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _generatePDF,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.bar_chart, size: 26),
                    label: const Text(
                      "View Number of \n Questions Per Course",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: _showCourseCountDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
