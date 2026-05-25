import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'ar/ar_screen.dart';
import 'map/capsule_locked_sheet.dart';
import 'map/map_config.dart';
import 'map/spot_3d_view_page.dart';
import 'map/tourist_spot_models.dart';
import '../services/tourist_spot_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  static const _defaultCenter = LatLng(37.5665, 126.9780);
  static const _accentColor = Color(0xFF1FAA8C);
  static const _bgColor = Color(0xFFF4F1EA);
  static const _textColor = Color(0xFF2E2B2A);
  static const _mutedColor = Color(0xFF7A756D);

  final _spotApi = TouristSpotApi();
  final _mapController = MapController();

  List<TouristSpot> _spots = const [];
  List<CapsuleMapMarker> _capsules = const [];
  SpotFilter _filter = SpotFilter.all;
  bool _showCapsules = true;
  bool _loading = true;
  bool _checkingIn = false;
  MapStyle _mapStyle = MapStyle.streets;
  LatLng? _userLatLng;
  StreamSubscription<Position>? _positionSub;
  AnimationController? _cameraAnim;

  @override
  void initState() {
    super.initState();
    _refresh();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _cameraAnim?.dispose();
    super.dispose();
  }

  /// 마커 탭 시 카메라가 해당 위치로 부드럽게 줌인.
  /// 한국엔 Mapbox 3D building 데이터가 거의 없어서 raster + 줌인으로 입체감 연출.
  void _flyTo(LatLng dest, {double zoom = 17}) {
    _cameraAnim?.dispose();
    final start = _mapController.camera.center;
    final startZoom = _mapController.camera.zoom;
    final anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOutCubic);
    anim.addListener(() {
      final t = curve.value;
      final lat = start.latitude + (dest.latitude - start.latitude) * t;
      final lng = start.longitude + (dest.longitude - start.longitude) * t;
      final z = startZoom + (zoom - startZoom) * t;
      final p = _safeLatLng(lat, lng);
      if (p == null) return;
      _mapController.move(p, z);
    });
    _cameraAnim = anim;
    anim.forward();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _spotApi.listSpots(),
      _spotApi.listCapsules(),
    ]);
    if (!mounted) return;
    setState(() {
      _spots = results[0] as List<TouristSpot>;
      _capsules = results[1] as List<CapsuleMapMarker>;
      _loading = false;
    });
  }

  Future<void> _startLocationUpdates() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final initial = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final initialLatLng = _safeLatLng(initial.latitude, initial.longitude);
      if (initialLatLng != null) {
        setState(() => _userLatLng = initialLatLng);
        _mapController.move(initialLatLng, 14);
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (!mounted) return;
        final next = _safeLatLng(position.latitude, position.longitude);
        if (next == null) return;
        setState(() => _userLatLng = next);
      });
    } catch (_) {}
  }

  static LatLng? _safeLatLng(double lat, double lon) {
    if (lat.isNaN || lon.isNaN || lat.isInfinite || lon.isInfinite) return null;
    if (lat == 0 && lon == 0) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return LatLng(lat, lon);
  }

  Future<void> _centerOnUser() async {
    final loc = _userLatLng;
    if (loc != null) {
      _mapController.move(loc, 15);
      return;
    }
    await _startLocationUpdates();
  }

  Iterable<TouristSpot> get _visibleSpots {
    switch (_filter) {
      case SpotFilter.all:
        return _spots;
      case SpotFilter.undiscovered:
        return _spots.where((s) => !s.visited);
      case SpotFilter.completed:
        return _spots.where((s) => s.visited);
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earth = 6371000.0;
    final rad = math.pi / 180;
    final dLat = (b.latitude - a.latitude) * rad;
    final dLon = (b.longitude - a.longitude) * rad;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * rad) *
            math.cos(b.latitude * rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earth * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> _discoverNearby() async {
    final user = _userLatLng;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 위치를 가져오지 못했어요.')),
      );
      return;
    }

    TouristSpot? nearest;
    double nearestDistance = double.infinity;
    for (final spot in _spots) {
      if (spot.visited) continue;
      final d = _distanceMeters(user, LatLng(spot.latitude, spot.longitude));
      if (d < nearestDistance) {
        nearest = spot;
        nearestDistance = d;
      }
    }

    if (nearest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 모든 관광지를 발견했어요!')),
      );
      return;
    }

    if (nearestDistance > nearest.radiusMeters) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '가장 가까운 미발견 장소까지 ${nearestDistance.toStringAsFixed(0)}m 남았어요.',
          ),
        ),
      );
      _mapController.move(LatLng(nearest.latitude, nearest.longitude), 15);
      return;
    }

    await _checkInSpot(nearest, source: 'manual');
  }

  Future<void> _checkInSpot(TouristSpot spot, {String source = 'ar'}) async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    final user = _userLatLng;
    final ok = await _spotApi.visitSpot(
      spotId: spot.id,
      source: source,
      latitude: user?.latitude,
      longitude: user?.longitude,
    );
    if (!mounted) return;
    setState(() => _checkingIn = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${spot.name}을(를) 발견했어요!')),
      );
      await _refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증에 실패했어요. 위치를 확인해주세요.')),
      );
    }
  }

  void _openSpotSheet(TouristSpot spot) {
    final spotLatLng = _safeLatLng(spot.latitude, spot.longitude);
    final user = _userLatLng;
    final isWithinRadius = user != null &&
        spotLatLng != null &&
        _distanceMeters(user, spotLatLng) <= spot.radiusMeters;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => Spot3DViewPage(
          spot: spot,
          isWithinRadius: isWithinRadius,
          onCheckIn: () => _checkInSpot(spot, source: 'manual'),
        ),
      ),
    )
        .then((_) {
      // 3D 페이지에서 돌아왔을 때 인증 상태 갱신 가능
      _refresh();
    });
  }

  void _openCapsuleSheet(CapsuleMapMarker capsule) {
    final capsuleLatLng = _safeLatLng(capsule.latitude, capsule.longitude);
    if (capsuleLatLng != null) {
      _flyTo(capsuleLatLng, zoom: 17);
    }
    String? spotName;
    for (final s in _spots) {
      if (s.visit?.capsuleId == capsule.id) {
        spotName = s.name;
        break;
      }
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CapsuleLockedSheet(capsule: capsule, spotName: spotName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visited = _spots.where((s) => s.visited).toList();
    final total = _spots.length;
    final progress = total == 0 ? 0.0 : visited.length / total;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          _buildMap(),
          _buildTopBar(),
          _buildLocationButton(),
          _buildBottomSheet(visited, total, progress),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (!MapConfig.hasValidToken) {
      return const _MissingTokenView();
    }
    final user = _userLatLng;
    final center = (user != null &&
            user.latitude.isFinite &&
            user.longitude.isFinite)
        ? user
        : _defaultCenter;
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13,
        minZoom: 5,
        maxZoom: 20,
        // 줌아웃 시 Mercator 좌표가 NaN 으로 발산하는 것을 방지.
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-85.0, -180.0),
            const LatLng(85.0, 180.0),
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrlTemplate(_mapStyle),
          userAgentPackageName: 'me.toricapsule.app',
          maxZoom: 22,
          tileSize: 512,
          zoomOffset: -1,
        ),
        MarkerLayer(markers: _buildMarkers()),
        const _MapboxAttribution(),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final spot in _visibleSpots) {
      final point = _safeLatLng(spot.latitude, spot.longitude);
      if (point == null) continue;
      markers.add(
        Marker(
          point: point,
          width: 56,
          height: 70,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _openSpotSheet(spot),
            child: _SpotMarker(spot: spot),
          ),
        ),
      );
    }

    if (_showCapsules) {
      for (final capsule in _capsules) {
        if (!capsule.isBuried) continue;
        final point = _safeLatLng(capsule.latitude, capsule.longitude);
        if (point == null) continue;
        markers.add(
          Marker(
            point: point,
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _openCapsuleSheet(capsule),
              child: _CapsuleMarker(locked: capsule.isLocked),
            ),
          ),
        );
      }
    }

    if (_userLatLng != null) {
      markers.add(
        Marker(
          point: _userLatLng!,
          width: 28,
          height: 28,
          child: const _UserMarker(),
        ),
      );
    }

    return markers;
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _showFilterMenu,
                icon: const Icon(Icons.tune, color: _textColor),
                tooltip: '필터',
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    '관광지 탐험 지도',
                    style: TextStyle(
                      fontFamily: 'Workbench',
                      color: _textColor,
                      fontSize: 18,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: _textColor),
                tooltip: '새로고침',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '관광지 필터',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: SpotFilter.values
                    .map(
                      (f) => ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        selectedColor: _accentColor.withValues(alpha: 0.2),
                        onSelected: (_) {
                          setState(() => _filter = f);
                          Navigator.of(context).pop();
                        },
                      ),
                    )
                    .toList(),
              ),
              const Divider(height: 32),
              const Text(
                '내가 묻은 캡슐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('지도에 캡슐 표시', style: TextStyle(color: _textColor)),
                value: _showCapsules,
                activeColor: _accentColor,
                onChanged: (value) {
                  setState(() => _showCapsules = value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Positioned(
      right: 16,
      bottom: 220,
      child: Column(
        children: [
          FloatingActionButton.small(
            heroTag: 'map_style',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: () {
              setState(() {
                _mapStyle = _mapStyle == MapStyle.streets
                    ? MapStyle.satellite
                    : MapStyle.streets;
              });
            },
            child: Icon(
              _mapStyle == MapStyle.streets
                  ? Icons.public_outlined
                  : Icons.map_outlined,
              color: _textColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'map_locate',
            backgroundColor: Colors.white,
            elevation: 4,
            onPressed: _centerOnUser,
            child: const Icon(Icons.my_location, color: _textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet(List<TouristSpot> visited, int total, double progress) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -2)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D5CC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              '발견한 관광지',
              style: TextStyle(
                fontFamily: 'Workbench',
                color: _mutedColor,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${visited.length}',
                  style: const TextStyle(
                    fontFamily: 'Workbench',
                    color: _accentColor,
                    fontSize: 30,
                  ),
                ),
                const Text(
                  ' / ',
                  style: TextStyle(
                    fontFamily: 'Workbench',
                    color: _mutedColor,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '$total',
                  style: const TextStyle(
                    fontFamily: 'Workbench',
                    color: _mutedColor,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE7E3D8),
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ..._buildVisitedAvatars(visited),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _discoverNearby,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.gps_fixed, size: 18),
                    label: const Text(
                      '근처에서 발견하기',
                      style: TextStyle(
                        fontFamily: 'Workbench',
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ArScreen()),
                      ).then((_) => _refresh());
                    },
                    icon: const Icon(Icons.view_in_ar, size: 18),
                    label: const Text(
                      'AR 인증',
                      style: TextStyle(
                        fontFamily: 'Workbench',
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFA14040),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVisitedAvatars(List<TouristSpot> visited) {
    const maxAvatars = 3;
    final avatars = <Widget>[];
    for (var i = 0; i < visited.length && i < maxAvatars; i++) {
      final spot = visited[i];
      avatars.add(
        Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: _VisitedAvatar(spot: spot),
        ),
      );
    }
    final remaining = visited.length - maxAvatars;
    if (remaining > 0) {
      avatars.add(
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD9D5CC), style: BorderStyle.solid),
            ),
            alignment: Alignment.center,
            child: Text(
              '+$remaining',
              style: const TextStyle(color: _mutedColor, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ),
      );
    }
    return avatars;
  }
}

class _SpotMarker extends StatelessWidget {
  const _SpotMarker({required this.spot});

  final TouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final visited = spot.visited;
    final color = visited ? spot.markerColor : const Color(0xFF3F3D3A);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // 그림자 (꼬리)
        Positioned(
          top: 40,
          child: CustomPaint(
            size: const Size(8, 14),
            painter: _MarkerTailPainter(color: color),
          ),
        ),
        // 본체 (펜던트)
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            visited ? spot.markerIcon : Icons.help_outline,
            color: Colors.white,
            size: 24,
          ),
        ),
        // 체크 배지 (발견 완료시만)
        if (visited)
          Positioned(
            top: 34,
            right: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.check, color: Colors.white, size: 11),
            ),
          ),
      ],
    );
  }
}

class _CapsuleMarker extends StatelessWidget {
  const _CapsuleMarker({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final color = locked ? const Color(0xFFA14040) : const Color(0xFF1FAA8C);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        locked ? Icons.lock_outline : Icons.lock_open_outlined,
        color: color,
        size: 18,
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

class _VisitedAvatar extends StatelessWidget {
  const _VisitedAvatar({required this.spot});

  final TouristSpot spot;

  @override
  Widget build(BuildContext context) {
    final color = spot.markerColor;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(spot.markerIcon, color: color, size: 18),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  _MarkerTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MissingTokenView extends StatelessWidget {
  const _MissingTokenView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF4F1EA),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.vpn_key_off_outlined, size: 48, color: Color(0xFF7A756D)),
          const SizedBox(height: 12),
          const Text(
            'Mapbox 토큰이 설정되지 않았어요',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E2B2A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '앱 실행 시 --dart-define=MAPBOX_TOKEN=pk.xxx 옵션을 전달해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF54514D)),
          ),
        ],
      ),
    );
  }
}

class _MapboxAttribution extends StatelessWidget {
  const _MapboxAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            '© Mapbox © OpenStreetMap',
            style: TextStyle(fontSize: 10, color: Color(0xFF54514D)),
          ),
        ),
      ),
    );
  }
}
