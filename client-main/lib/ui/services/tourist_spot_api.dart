import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../pages/map/tourist_spot_models.dart';
import 'auth_api.dart';

class TouristSpotApi {
  TouristSpotApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String get _baseUrl => AuthApi.baseUrl;

  Future<List<TouristSpot>> listSpots() async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('listSpots: not signed in');
      return const [];
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/tourist-spots',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = response.data;
      if (raw is! Map) return const [];
      final spots = raw['spots'];
      if (spots is! List) return const [];
      return spots
          .whereType<Map>()
          .map((e) => TouristSpot.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (error) {
      debugPrint('listSpots failed: $error');
      return const [];
    }
  }

  Future<List<CapsuleMapMarker>> listCapsules() async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('listCapsules: not signed in');
      return const [];
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/capsules',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final raw = response.data;
      if (raw is! Map) return const [];
      final capsules = raw['capsules'];
      if (capsules is! List) return const [];
      final markers = <CapsuleMapMarker>[];
      for (final item in capsules) {
        if (item is! Map) continue;
        final marker = CapsuleMapMarker.fromJson(Map<String, dynamic>.from(item));
        if (marker != null) markers.add(marker);
      }
      return markers;
    } catch (error) {
      debugPrint('listCapsules failed: $error');
      return const [];
    }
  }

  /// Mark a tourist spot as visited.
  /// [source] is one of "ar", "capsule", "manual".
  /// When [latitude]/[longitude] are passed the server validates the radius.
  Future<bool> visitSpot({
    required String spotId,
    String source = 'ar',
    String? capsuleId,
    double? latitude,
    double? longitude,
  }) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('visitSpot: not signed in');
      return false;
    }

    try {
      final formData = FormData.fromMap({
        'source': source,
        if (capsuleId != null && capsuleId.isNotEmpty) 'capsule_id': capsuleId,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
      });
      await _dio.post(
        '$_baseUrl/tourist-spots/$spotId/visit',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (error) {
      debugPrint('visitSpot failed: $error');
      return false;
    }
  }
}
