import 'package:flutter/material.dart';

enum SpotFilter {
  all,
  undiscovered,
  completed,
}

extension SpotFilterLabel on SpotFilter {
  String get label {
    switch (this) {
      case SpotFilter.all:
        return '전체';
      case SpotFilter.undiscovered:
        return '미발견';
      case SpotFilter.completed:
        return '완료';
    }
  }
}

enum VisitSource {
  capsule,
  ar,
  manual,
  unknown,
}

VisitSource _parseVisitSource(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'capsule':
      return VisitSource.capsule;
    case 'ar':
      return VisitSource.ar;
    case 'manual':
      return VisitSource.manual;
    default:
      return VisitSource.unknown;
  }
}

class TouristSpotVisit {
  const TouristSpotVisit({
    required this.source,
    this.capsuleId,
    this.visitedAt,
  });

  final VisitSource source;
  final String? capsuleId;
  final DateTime? visitedAt;

  static TouristSpotVisit? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final capsule = (json['capsule'] ?? '').toString().trim();
    DateTime? visited;
    final raw = json['visited_at'];
    if (raw != null && raw.toString().isNotEmpty) {
      visited = DateTime.tryParse(raw.toString());
    }
    return TouristSpotVisit(
      source: _parseVisitSource(json['source']?.toString()),
      capsuleId: capsule.isEmpty ? null : capsule,
      visitedAt: visited,
    );
  }
}

class TouristSpot {
  const TouristSpot({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.visited,
    this.description,
    this.category,
    this.iconKey,
    this.colorHex,
    this.imageUrl,
    this.visit,
  });

  final String id;
  final String code;
  final String name;
  final String? description;
  final String? category;
  final String? iconKey;
  final String? colorHex;
  final String? imageUrl;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool visited;
  final TouristSpotVisit? visit;

  factory TouristSpot.fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    double lat = 0;
    double lon = 0;
    if (loc is Map) {
      lat = (loc['lat'] as num?)?.toDouble() ?? 0;
      lon = (loc['lon'] as num?)?.toDouble() ?? 0;
    }
    final visitJson = json['visit'];
    return TouristSpot(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
      iconKey: json['icon']?.toString(),
      colorHex: json['color']?.toString(),
      imageUrl: json['image_url']?.toString(),
      latitude: lat,
      longitude: lon,
      radiusMeters: (json['radius_m'] as num?)?.toInt() ?? 200,
      visited: json['visited'] == true,
      visit: visitJson is Map<String, dynamic>
          ? TouristSpotVisit.fromJson(visitJson)
          : null,
    );
  }

  Color get markerColor {
    final hex = (colorHex ?? '').replaceAll('#', '');
    if (hex.length == 6) {
      final value = int.tryParse('FF$hex', radix: 16);
      if (value != null) return Color(value);
    }
    return const Color(0xFF1FAA8C);
  }

  IconData get markerIcon {
    switch (iconKey) {
      case 'castle':
        return Icons.castle_outlined;
      case 'tower':
        return Icons.cell_tower_outlined;
      case 'gate':
        return Icons.account_balance_outlined;
      case 'village':
        return Icons.holiday_village_outlined;
      case 'street':
        return Icons.storefront_outlined;
      case 'modern':
        return Icons.location_city_outlined;
      case 'park':
        return Icons.park_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

class CapsuleMapMarker {
  const CapsuleMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.canOpenNow,
    this.emotion,
    this.createdAt,
    this.buriedAt,
    this.openAt,
    this.openOption,
    this.openAfterDays,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String status;
  final bool canOpenNow;
  final String? emotion;
  final DateTime? createdAt;
  final DateTime? buriedAt;
  final DateTime? openAt;
  final String? openOption;
  final int? openAfterDays;

  static CapsuleMapMarker? fromJson(Map<String, dynamic> json) {
    final loc = json['location'];
    double? lat;
    double? lon;
    if (loc is Map) {
      lat = (loc['lat'] as num?)?.toDouble();
      lon = (loc['lon'] as num?)?.toDouble();
    }
    if (lat == null || lon == null) return null;

    final openMap = json['open'] is Map<String, dynamic>
        ? json['open'] as Map<String, dynamic>
        : <String, dynamic>{};

    DateTime? parseDate(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return CapsuleMapMarker(
      id: (json['id'] ?? '').toString(),
      latitude: lat,
      longitude: lon,
      status: (json['status'] ?? '').toString(),
      emotion: json['emotion']?.toString(),
      createdAt: parseDate(json['created']),
      buriedAt: parseDate(json['buried_at']),
      openAt: parseDate(openMap['open_at']),
      openOption: openMap['open_option']?.toString(),
      openAfterDays: (openMap['open_after_days'] as num?)?.toInt(),
      canOpenNow: openMap['can_open_now'] == true,
    );
  }

  bool get isLocked => !canOpenNow;
  bool get isBuried => status == 'buried';
}
