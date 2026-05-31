// lib/backoffice/pages/bk_courses/courses_service.dart

// -----------------------------------------------------------------------------
// IMPORT
// -----------------------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex;

import '../../../main.dart'; // per formDb

// -----------------------------------------------------------------------------
// COURSES SERVICE
// -----------------------------------------------------------------------------
class CoursesService {
  CoursesService._();

  // ---------------------------------------------------------------------------
  // PARSE QUIZ XLSX
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> parseQuizXlsx() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return null;

    final file = result.files.single;
    final bytes = file.bytes!;
    final excel = ex.Excel.decodeBytes(bytes);

    final List<Map<String, dynamic>> questions = [];

    for (final table in excel.tables.keys) {
      for (var row in excel.tables[table]!.rows.skip(1)) {
        if (row.isEmpty) continue;

        questions.add({
          "question": row[0]?.value.toString() ?? "",
          "options": [
            row[1]?.value.toString() ?? "",
            row[2]?.value.toString() ?? "",
            row[3]?.value.toString() ?? "",
          ],
          "correctIndex":
          int.tryParse(row[4]?.value.toString() ?? "0") ?? 0,
        });
      }
    }

    return {
      "fileName": file.name,
      "timeLimit": 300,
      "questions": questions,
    };
  }

  // ---------------------------------------------------------------------------
  // CREATE COURSE
  // ---------------------------------------------------------------------------
  static Future<DocumentReference> createCourseSkeleton() async {
    final newCourseRef =
    formDb.collection('courses').doc();

    await newCourseRef.set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return newCourseRef;
  }

  // ---------------------------------------------------------------------------
  // SAVE COURSE DEFINITIVE
  // ---------------------------------------------------------------------------
  static Future<void> saveCourse({
    required DocumentReference courseRef,
    required String title,
    required String description,
    required String category,
    required String videoUrl,
    required List<String> tags,
    required List<String> contents,
    required List<String> attachments,
    Map<String, dynamic>? quizData,
  }) async {
    await FirebaseAuth.instance.currentUser
        ?.getIdToken(true);

    await courseRef.set({
      'title': title,
      'description': description,
      'category': category,
      'videoUrl': videoUrl,
      'tags': tags,
      'contents': contents,
      'attachments': attachments,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _createUserProgressForAllUsers(
      courseId: courseRef.id,
      title: title,
      category: category,
    );

    if (quizData != null) {
      await formDb.collection('quiz').add({
        'courseId': courseRef.id,
        'title': title,
        'fileName': quizData['fileName'],
        'difficulty': 'medium',
        'timeLimit': quizData['timeLimit'],
        'questions': quizData['questions'],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UPDATE COURSE
  // ---------------------------------------------------------------------------
  static Future<void> updateCourse({
    required DocumentReference courseRef,
    required String title,
    required String description,
    required String category,
    required String videoUrl,
    required List<String> tags,
    required List<String> contents,
    required List<String> attachments,
    Map<String, dynamic>? quizData,
  }) async {
    await FirebaseAuth.instance.currentUser
        ?.getIdToken(true);

    await courseRef.update({
      'title': title,
      'description': description,
      'category': category,
      'videoUrl': videoUrl,
      'tags': tags,
      'contents': contents,
      'attachments': attachments,
    });

    if (quizData != null) {
      final quizSnap = await formDb
          .collection('quiz')
          .where('courseId',
          isEqualTo: courseRef.id)
          .limit(1)
          .get();

      if (quizSnap.docs.isNotEmpty) {
        await quizSnap.docs.first.reference.update({
          'fileName': quizData['fileName'],
          'questions': quizData['questions'],
          'title': title,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await formDb.collection('quiz').add({
          'courseId': courseRef.id,
          'title': title,
          'fileName': quizData['fileName'],
          'difficulty': 'medium',
          'timeLimit': quizData['timeLimit'],
          'questions': quizData['questions'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // DELETE COURSE COMPLETELY
  // ---------------------------------------------------------------------------
  static Future<void> deleteCourseCompletely(
      DocumentReference courseRef) async {
    final courseId = courseRef.id;

    // elimina quiz
    final quizSnap = await formDb
        .collection('quiz')
        .where('courseId', isEqualTo: courseId)
        .get();

    for (final q in quizSnap.docs) {
      await q.reference.delete();
    }

    // elimina progressi utenti
    final usersSnap =
    await formDb.collection('userProgress').get();

    for (final user in usersSnap.docs) {
      final courseSnap = await user.reference
          .collection('courses')
          .where('courseId', isEqualTo: courseId)
          .get();

      for (final c in courseSnap.docs) {
        await c.reference.delete();
      }
    }

    await courseRef.delete();
  }

  // ---------------------------------------------------------------------------
  // PRIVATE - CREATE USER PROGRESS
  // ---------------------------------------------------------------------------
  static Future<void>
  _createUserProgressForAllUsers({
    required String courseId,
    required String title,
    required String category,
  }) async {
    final users =
    await formDb.collection('users').get();

    for (var user in users.docs) {
      await formDb
          .collection('userProgress')
          .doc(user.id)
          .collection('courses')
          .doc(courseId)
          .set({
        'title': title,
        'courseId': courseId,
        'category': category,
        'lastQuizDate': null,
        'lastScore': 0,
        'quizAttempts': 0,
        'videoViews': 0,
        'downloadCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
