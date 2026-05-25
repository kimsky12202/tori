import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_api.dart';

class ChallengeApiException implements Exception {
  const ChallengeApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChallengeItem {
  const ChallengeItem({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.category,
    required this.conditionType,
    required this.conditionValue,
    required this.progressValue,
    required this.status,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String category;
  final String conditionType;
  final int conditionValue;
  final int progressValue;
  final String status;

  bool get isCompleted => status == 'completed';
  bool get isClaimed => status == 'claimed';
  bool get canClaim => isCompleted && !isClaimed;

  double get progressRate {
    if (conditionValue <= 0) {
      return 0;
    }

    final double ratio = progressValue / conditionValue;
    if (ratio < 0) {
      return 0;
    }
    if (ratio > 1) {
      return 1;
    }
    return ratio;
  }
}

class ChallengeApi {
  ChallengeApi({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<ChallengeItem>> listMyChallenges() async {
    final String token = _requireAccessToken();

    final response = await _httpClient.get(
      Uri.parse('${AuthApi.baseUrl}/challenges/me'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw ChallengeApiException(_extractErrorMessage(response));
    }

    final dynamic data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const ChallengeApiException('invalid response from server');
    }

    final dynamic challengesData = data['challenges'];
    if (challengesData is! List) {
      return const <ChallengeItem>[];
    }

    return challengesData
        .map((dynamic item) => _parseChallengeItem(item))
        .whereType<ChallengeItem>()
        .toList();
  }

  Future<void> claimChallenge({required String challengeId}) async {
    final String token = _requireAccessToken();

    final response = await _httpClient.post(
      Uri.parse('${AuthApi.baseUrl}/challenges/$challengeId/claim'),
      headers: <String, String>{'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ChallengeApiException(_extractErrorMessage(response));
  }

  String _requireAccessToken() {
    final String? token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      throw const ChallengeApiException('로그인 정보가 없습니다. 다시 로그인해주세요.');
    }
    return token;
  }

  ChallengeItem? _parseChallengeItem(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
    return ChallengeItem(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      conditionType: (json['condition_type'] ?? '').toString(),
      conditionValue: _toInt(json['condition_value']),
      progressValue: _toInt(json['progress_value']),
      status: (json['status'] ?? 'in_progress').toString(),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      if (body is Map<String, dynamic> && body['message'] != null) {
        return body['message'].toString();
      }
    } catch (_) {
      // Falls back to generic message when response body is not JSON.
    }

    return 'request failed: ${response.statusCode}';
  }
}
