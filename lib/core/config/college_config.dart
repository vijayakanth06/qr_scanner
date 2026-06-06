import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Roll number pattern configuration for a college ID card.
class RollPattern {
  const RollPattern({required this.rollPattern});

  final String rollPattern;

  factory RollPattern.fromJson(Map<String, dynamic> json) {
    final pattern = json['rollPattern'] as String?;
    if (pattern == null || pattern.trim().isEmpty) {
      throw const FormatException('Missing required field: idCardFormat.rollPattern');
    }
    return RollPattern(rollPattern: pattern);
  }
}

/// Sync behaviour configuration.
class SyncPolicy {
  const SyncPolicy({required this.maxIncrementalGap, required this.cooldownSeconds});

  final int maxIncrementalGap;
  final int cooldownSeconds;

  factory SyncPolicy.fromJson(Map<String, dynamic> json) {
    final gap = json['maxIncrementalGap'];
    final cooldown = json['cooldownSeconds'];

    if (gap is! num) {
      throw const FormatException('Missing or invalid field: syncPolicy.maxIncrementalGap');
    }
    if (cooldown is! num) {
      throw const FormatException('Missing or invalid field: syncPolicy.cooldownSeconds');
    }

    return SyncPolicy(
      maxIncrementalGap: gap.toInt(),
      cooldownSeconds: cooldown.toInt(),
    );
  }
}

/// Strongly-typed configuration for a single college tenant.
class CollegeConfig {
  const CollegeConfig({
    required this.collegeId,
    required this.collegeName,
    required this.logoUrl,
    required this.firebaseDatabaseURL,
    required this.idCardFormat,
    required this.syncPolicy,
  });

  final String collegeId;
  final String collegeName;
  final String logoUrl;
  final String firebaseDatabaseURL;
  final RollPattern idCardFormat;
  final SyncPolicy syncPolicy;

  factory CollegeConfig.fromJson(Map<String, dynamic> json) {
    String _requireString(Map<String, dynamic> source, String key) {
      final value = source[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Missing or invalid field: $key');
      }
      return value.trim();
    }

    final idCard = json['idCardFormat'];
    final syncPolicy = json['syncPolicy'];

    if (idCard is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid field: idCardFormat');
    }
    if (syncPolicy is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid field: syncPolicy');
    }

    return CollegeConfig(
      collegeId: _requireString(json, 'collegeId'),
      collegeName: _requireString(json, 'collegeName'),
      logoUrl: _requireString(json, 'logoUrl'),
      firebaseDatabaseURL: _requireString(json, 'firebaseDatabaseURL'),
      idCardFormat: RollPattern.fromJson(idCard),
      syncPolicy: SyncPolicy.fromJson(syncPolicy),
    );
  }

  /// Parse [rawJson] into [CollegeConfig] with helpful error messages.
  static CollegeConfig parse(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('College config JSON must be a JSON object');
      }
      return CollegeConfig.fromJson(decoded);
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Failed to parse college config: $error');
    }
  }

  static Future<List<CollegeConfig>> loadAll() async {
    final jsonStr = await rootBundle.loadString('assets/colleges.json');
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => CollegeConfig.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
