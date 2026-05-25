import 'package:flutter/foundation.dart';

/// 지도(Mapbox) 설정.
///
/// 토큰은 코드에 절대 넣지 말고 빌드 시 --dart-define으로 주입한다:
///   flutter run --dart-define=MAPBOX_TOKEN=pk.your_token_here
///
/// IDE에서 실행할 경우 launch.json / additional run args 에도 동일하게 추가.
class MapConfig {
  static const String mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: '',
  );

  static const String mapboxStyleId = String.fromEnvironment(
    'MAPBOX_STYLE',
    defaultValue: 'mapbox/streets-v12',
  );

  static const int tileSize = 512;

  /// Mapbox raster tiles API.
  /// 512px 레티나 타일 사용 (flutter_map TileLayer 에서 tileSize: 512, zoomOffset: -1 함께 설정).
  static String get tileUrlTemplate {
    return 'https://api.mapbox.com/styles/v1/$mapboxStyleId/tiles/$tileSize/{z}/{x}/{y}@2x?access_token=$mapboxToken';
  }

  static bool get hasValidToken {
    final t = mapboxToken.trim();
    final ok = t.isNotEmpty && t.startsWith('pk.');
    if (!ok && kDebugMode) {
      debugPrint(
        'MapConfig: MAPBOX_TOKEN 미설정. --dart-define=MAPBOX_TOKEN=pk.xxx 로 전달하세요.',
      );
    }
    return ok;
  }
}
