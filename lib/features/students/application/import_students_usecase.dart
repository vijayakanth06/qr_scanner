import 'dart:typed_data';

import 'package:qr_scanner/features/students/data/student_import_service.dart';
import 'package:qr_scanner/features/students/domain/entities/student.dart';
import 'package:qr_scanner/features/students/domain/repositories/student_repository.dart';

class ImportStudentsUseCase {
  ImportStudentsUseCase({
    required this.importService,
    this.studentRepository,
  });

  final StudentImportService importService;
  final StudentRepository? studentRepository;

  Future<int> call({
    required String extension,
    required Uint8List bytes,
  }) async {
    final ext = extension.trim().toLowerCase();
    final List<Student> parsed;

    if (ext == 'csv') {
      final content = String.fromCharCodes(bytes);
      parsed = importService.parseCsv(content);
    } else if (ext == 'xlsx') {
      parsed = importService.parseExcel(bytes);
    } else {
      throw ArgumentError('Unsupported import type: $ext');
    }

    if (parsed.isEmpty) {
      return 0;
    }

    // Optional: upsert to local database if repository provided
    // For Firebase-only setup, repository can be null
    if (studentRepository != null) {
      await studentRepository!.upsertAll(parsed);
    }
    
    return parsed.length;
  }
}
