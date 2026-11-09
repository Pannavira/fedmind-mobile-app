import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/multimodal_inspection_models.dart';
import '../models/screening_models.dart';

class ScreeningLocalDataSource {
  static const String databaseName = 'fedmind_clinical.db';
  static const int databaseVersion = 1;
  static const String tableName = 'screenings';

  Database? _database;
  final Future<Database> Function()? customDbOpener;

  ScreeningLocalDataSource({
    Database? initialDatabase,
    this.customDbOpener,
  }) : _database = initialDatabase;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final opener = customDbOpener;
    if (opener != null) {
      _database = await opener();
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: onCreate,
    );
  }

  static Future<void> onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        screening_id TEXT PRIMARY KEY,
        participant_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        completed_at TEXT,
        status TEXT NOT NULL,
        phq8_score REAL,
        risk_category TEXT,
        binary_prediction TEXT,
        dominant_modality TEXT,
        video_path TEXT,
        full_result_json TEXT NOT NULL,
        inspection_json TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_screenings_participant ON $tableName (participant_id)',
    );
    await db.execute(
      'CREATE INDEX idx_screenings_created_at ON $tableName (created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_screenings_risk ON $tableName (risk_category)',
    );
  }

  /// Menyimpan atau memperbarui hasil skrining ke SQLite lokal
  Future<void> insertOrUpdateScreening({
    required ScreeningResponse screening,
    MultimodalInspectionData? inspectionData,
    String? videoPath,
  }) async {
    final db = await database;

    // Jika inspectionData atau videoPath tidak diberikan saat update, pertahankan nilai yang sudah ada di DB
    String? effectiveInspectionJson =
        inspectionData != null ? jsonEncode(inspectionData.toJson()) : null;
    String? effectiveVideoPath = videoPath;

    if (effectiveInspectionJson == null || effectiveVideoPath == null) {
      final existing = await db.query(
        tableName,
        columns: ['inspection_json', 'video_path'],
        where: 'screening_id = ?',
        whereArgs: [screening.screeningId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        effectiveInspectionJson ??= existing.first['inspection_json'] as String?;
        effectiveVideoPath ??= existing.first['video_path'] as String?;
      }
    }

    final row = <String, dynamic>{
      'screening_id': screening.screeningId,
      'participant_id': screening.participantId,
      'created_at': screening.createdAt ?? DateTime.now().toIso8601String(),
      'completed_at': screening.completedAt,
      'status': screening.status,
      'phq8_score': screening.prediction?.phq8Score,
      'risk_category': screening.prediction?.riskCategory,
      'binary_prediction': screening.prediction?.binaryPrediction,
      'dominant_modality':
          screening.patientModalityAttribution?.dominantModality ?? 'visual',
      'video_path': effectiveVideoPath,
      'full_result_json': jsonEncode(screening.toJson()),
      'inspection_json': effectiveInspectionJson,
    };

    await db.insert(
      tableName,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Menyimpan verifikasi klinis konselor (Concordance, Ground Truth PHQ-8, Audit Modalitas, & Catatan SOAP)
  Future<ScreeningResponse?> saveClinicalVerification({
    required String screeningId,
    required ClinicalVerificationData verification,
  }) async {
    final existing = await getScreeningDetail(screeningId);
    if (existing == null) return null;

    final updated = existing.copyWithVerification(verification);
    await insertOrUpdateScreening(screening: updated);
    return updated;
  }

  /// Mengambil daftar riwayat (summary) dengan pagination dan filter
  Future<List<ScreeningSummaryItem>> getScreeningHistory({
    int skip = 0,
    int limit = 50,
    String? participantId,
    String? riskCategory,
  }) async {
    final db = await database;

    String? whereClause;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (participantId != null && participantId.trim().isNotEmpty) {
      conditions.add('participant_id LIKE ?');
      args.add('%${participantId.trim()}%');
    }

    if (riskCategory != null &&
        riskCategory.trim().isNotEmpty &&
        riskCategory.trim().toLowerCase() != 'all') {
      conditions.add('LOWER(risk_category) = ?');
      args.add(riskCategory.trim().toLowerCase());
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
      whereArgs = args;
    }

    final maps = await db.query(
      tableName,
      columns: [
        'screening_id',
        'participant_id',
        'status',
        'phq8_score',
        'risk_category',
        'binary_prediction',
        'dominant_modality',
        'created_at',
        'completed_at',
        'full_result_json',
      ],
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: skip,
    );

    return maps.map((row) {
      ClinicalVerificationData? verification;
      final fullJsonStr = row['full_result_json'] as String?;
      if (fullJsonStr != null && fullJsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(fullJsonStr) as Map<String, dynamic>;
          if (decoded['clinical_verification'] != null) {
            verification = ClinicalVerificationData.fromJson(
              decoded['clinical_verification'] as Map<String, dynamic>,
            );
          }
        } catch (_) {}
      }

      return ScreeningSummaryItem(
        screeningId: row['screening_id'] as String,
        participantId: row['participant_id'] as String,
        status: row['status'] as String,
        phq8Score: (row['phq8_score'] as num?)?.toDouble(),
        riskCategory: row['risk_category'] as String?,
        binaryPrediction: row['binary_prediction'] as String?,
        dominantModality: row['dominant_modality'] as String?,
        createdAt: row['created_at'] as String,
        completedAt: row['completed_at'] as String?,
        isVerified: verification?.isVerified ?? false,
        concordanceStatus: verification?.concordanceStatus,
        groundTruthPhq8: verification?.groundTruthPhq8,
      );
    }).toList();
  }

  /// Mengambil detail lengkap ScreeningResponse dari SQLite
  Future<ScreeningResponse?> getScreeningDetail(String screeningId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      columns: ['full_result_json'],
      where: 'screening_id = ?',
      whereArgs: [screeningId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final jsonStr = results.first['full_result_json'] as String;
    return ScreeningResponse.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  /// Mengambil data inspeksi multimodal (fitur visual, audio, teks, dan koalisi)
  Future<MultimodalInspectionData?> getInspectionData(
    String screeningId,
  ) async {
    final db = await database;
    final results = await db.query(
      tableName,
      columns: ['inspection_json'],
      where: 'screening_id = ?',
      whereArgs: [screeningId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    final jsonStr = results.first['inspection_json'] as String?;
    if (jsonStr == null || jsonStr.isEmpty) return null;
    return MultimodalInspectionData.fromJson(
      jsonDecode(jsonStr) as Map<String, dynamic>,
    );
  }

  /// Mengambil path video lokal tersimpan
  Future<String?> getVideoPath(String screeningId) async {
    final db = await database;
    final results = await db.query(
      tableName,
      columns: ['video_path'],
      where: 'screening_id = ?',
      whereArgs: [screeningId],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['video_path'] as String?;
  }

  /// Menghitung total data skrining tersimpan
  Future<int> getTotalCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $tableName'),
    );
    return count ?? 0;
  }

  /// Menghapus satu data skrining
  Future<bool> deleteScreening(String screeningId) async {
    final db = await database;
    final deleted = await db.delete(
      tableName,
      where: 'screening_id = ?',
      whereArgs: [screeningId],
    );
    return deleted > 0;
  }

  /// Menghapus seluruh data skrining lokal
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(tableName);
  }

  /// Menutup koneksi database
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
