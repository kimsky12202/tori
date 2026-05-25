import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../pages/capsule/capsule_content_sheet.dart';
import 'auth_api.dart';

class CapsuleApi {
  static const baseUrl = 'https://www.tori-capsule.me';
  final _dio = Dio();

  Future<String?> createCapsule({
    required CapsuleData data,
    required double latitude,
    required double longitude,
    List<String> memberIds = const [],
  }) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('createCapsule: not signed in');
      return null;
    }

    try {
      final formData = FormData();

      formData.fields.addAll([
        MapEntry('latitude', latitude.toString()),
        MapEntry('longitude', longitude.toString()),
        MapEntry('status', 'created'),
        MapEntry('open_option', data.openOption),
        if (data.openAfterDays != null)
          MapEntry('open_after_days', data.openAfterDays!.toString()),
        if (data.memo != null) MapEntry('memo', data.memo!),
        if (data.emotion != null) MapEntry('emotion', data.emotion!),
        if (data.musicTitle != null) MapEntry('music_title', data.musicTitle!),
        if (data.musicArtist != null)
          MapEntry('music_artist', data.musicArtist!),
      ]);

      for (final memberId in memberIds) {
        final trimmed = memberId.trim();
        if (trimmed.isEmpty) continue;
        formData.fields.add(MapEntry('member_ids', trimmed));
      }

      for (final photo in data.photos) {
        formData.files.add(
          MapEntry('photos', await MultipartFile.fromFile(photo.path)),
        );
      }

      for (final video in data.videos) {
        formData.files.add(
          MapEntry('videos', await MultipartFile.fromFile(video.path)),
        );
      }

      if (data.musicFile != null) {
        formData.files.add(
          MapEntry('music', await MultipartFile.fromFile(data.musicFile!.path)),
        );
      }

      final response = await _dio.post(
        '$baseUrl/capsules',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.data['capsule']['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<bool> buryCapsule({required String capsuleId}) async {
    final token = AuthApi.accessToken;
    if (token == null || token.isEmpty) {
      debugPrint('buryCapsule: not signed in');
      return false;
    }

    try {
      await _dio.patch(
        '$baseUrl/capsules/$capsuleId/bury',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
