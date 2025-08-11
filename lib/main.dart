import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class Student {
  String name;
  Map<String, double> grades;

  Student({required this.name, required this.grades});

  double get total => grades.values.fold(0, (sum, val) => sum + val);

  double get percentage {
    if (grades.isEmpty) return 0;
    double maxTotal = grades.length * 100;
    return (total / maxTotal) * 100;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'grades': grades,
      };

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      name: json['name'],
      grades: Map<String, double>.from((json['grades'] as Map)
          .map((key, value) => MapEntry(key, value + 0.0))),
    );
  }
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Student> students = [];
  final _studentNameController = TextEditingController();
  final _subjectNameController = TextEditingController();
  String? currentSelectedStudent;
  List<String> subjects = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString('students_data');
    if (data != null) {
      List<dynamic> jsonList = jsonDecode(data);
      students = jsonList.map((e) => Student.fromJson(e)).toList();
      if (students.isNotEmpty) {
        subjects = students[0].grades.keys.toList();
      }
      setState(() {});
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> jsonList =
        students.map((student) => student.toJson()).toList();
    prefs.setString('students_data', jsonEncode(jsonList));
  }

  Future<void> clearData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('students_data');
    students.clear();
    subjects.clear();
    currentSelectedStudent = null;
    setState(() {});
  }

  void addStudent() {
    String name = _studentNameController.text.trim();
    if (name.isEmpty) {
      showError('اسم الطالب لا يمكن أن يكون فارغًا');
      return;
    }
    if (students.length >= 1000) {
      showError('تم الوصول للحد الأقصى (1000 طالب)');
      return;
    }
    if (students.any((s) => s.name == name)) {
      showError('هذا الطالب موجود مسبقًا');
      return;
    }
    Map<String, double> emptyGrades = {};
    for (var subj in subjects) {
      emptyGrades[subj] = 0;
    }
    students.add(Student(name: name, grades: emptyGrades));
    currentSelectedStudent = name;
    _studentNameController.clear();
    saveData();
    setState(() {});
  }

  void addSubject() {
    String subject = _subjectNameController.text.trim();
    if (subject.isEmpty) {
      showError('اسم المادة لا يمكن أن يكون فارغًا');
      return;
    }
    if (subjects.contains(subject)) {
      showError('المادة موجودة مسبقًا');
      return;
    }
    subjects.add(subject);
    for (var student in students) {
      student.grades[subject] = 0;
    }
    _subjectNameController.clear();
    saveData();
    setState(() {});
  }

  void updateGrade(String studentName, String subject, String value) {
    double? grade = double.tryParse(value);
    if (grade == null || grade < 0 || grade > 100) {
      showError('الدرجة يجب أن تكون بين 0 و 100');
      return;
    }
    final student = students.firstWhere((s) => s.name == studentName);
    student.grades[subject] = grade;
    saveData();
    setState(() {});
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'برنامج إدارة درجات الطلاب',
      home: Scaffold(
        appBar: AppBar(
          title: Text('برنامج إدارة درجات الطلاب'),
          actions: [
            IconButton(
              icon: Icon(Icons.delete_forever),
              tooltip: 'إنشاء جدول جديد (مسح البيانات)',
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                          title: Text('تأكيد'),
                          content:
                              Text('هل تريد مسح كل البيانات وإنشاء جدول جديد؟'),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  clearData();
                                  Navigator.pop(context);
                                },
                                child: Text('نعم')),
                            TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text('لا')),
                          ],
                        ));
              },
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _studentNameController,
                      decoration: InputDecoration(labelText: 'اسم الطالب'),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: addStudent,
                    child: Text('إضافة طالب'),
                  )
                ],
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subjectNameController,
                      decoration: InputDecoration(labelText: 'اسم المادة'),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: addSubject,
                    child: Text('إضافة مادة'),
                  )
                ],
              ),
              SizedBox(height: 20),
              Expanded(
                child: students.isEmpty
                    ? Center(child: Text('لا يوجد طلاب بعد'))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text('اسم الطالب')),
                            ...subjects
                                .map((s) => DataColumn(label: Text(s)))
                                .toList(),
                            DataColumn(label: Text('المجموع')),
                            DataColumn(label: Text('النسبة %')),
                          ],
                          rows: students.map((student) {
                            return DataRow(
                              cells: [
                                DataCell(Text(student.name)),
                                ...subjects.map((subject) {
                                  return DataCell(
                                    SizedBox(
                                      width: 50,
                                      child: TextFormField(
                                        initialValue: student
                                                .grades[subject]
                                                ?.toStringAsFixed(1) ??
                                            '0',
                                        keyboardType: TextInputType.number,
                                        onFieldSubmitted: (val) {
                                          updateGrade(student.name, subject, val);
                                        },
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                DataCell(Text(student.total.toStringAsFixed(1))),
                                DataCell(
                                    Text(student.percentage.toStringAsFixed(2))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
