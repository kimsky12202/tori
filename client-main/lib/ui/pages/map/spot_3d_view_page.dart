import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'map_config.dart';
import 'tourist_spot_models.dart';

/// Mapbox GL JS fill-extrusion 으로 3D 빌딩을 렌더링하는 풀스크린 페이지.
/// flutter_map (raster-only) 으로는 이 효과가 불가능해서 WebView 로 띄움.
class Spot3DViewPage extends StatefulWidget {
  const Spot3DViewPage({
    super.key,
    required this.spot,
    this.isWithinRadius = false,
    this.onCheckIn,
  });

  final TouristSpot spot;
  final bool isWithinRadius;
  final VoidCallback? onCheckIn;

  @override
  State<Spot3DViewPage> createState() => _Spot3DViewPageState();
}

class _Spot3DViewPageState extends State<Spot3DViewPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEDE9E1))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    final lat = widget.spot.latitude;
    final lon = widget.spot.longitude;
    final token = MapConfig.mapboxToken;
    final markerColor = '#${widget.spot.colorHex?.replaceAll('#', '') ?? '1FAA8C'}';
    final name = widget.spot.name.replaceAll("'", "\\'");

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no" />
  <title>3D</title>
  <link href="https://api.mapbox.com/mapbox-gl-js/v3.7.0/mapbox-gl.css" rel="stylesheet" />
  <script src="https://api.mapbox.com/mapbox-gl-js/v3.7.0/mapbox-gl.js"></script>
  <style>
    body, html, #map { margin: 0; padding: 0; height: 100%; width: 100%; background: #EDE9E1; }
    .mapboxgl-ctrl-attrib { font-size: 9px; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    mapboxgl.accessToken = '$token';
    const map = new mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/streets-v12',
      center: [$lon, $lat],
      zoom: 16.2,
      pitch: 62,
      bearing: -18,
      antialias: true
    });

    map.on('style.load', () => {
      const layers = map.getStyle().layers;
      let labelLayerId;
      for (const layer of layers) {
        if (layer.type === 'symbol' && layer.layout && layer.layout['text-field']) {
          labelLayerId = layer.id;
          break;
        }
      }
      map.addLayer({
        'id': '3d-buildings',
        'source': 'composite',
        'source-layer': 'building',
        'filter': ['==', 'extrude', 'true'],
        'type': 'fill-extrusion',
        'minzoom': 14,
        'paint': {
          'fill-extrusion-color': '#9aa1a8',
          'fill-extrusion-height': [
            'interpolate', ['linear'], ['zoom'],
            14, 0,
            14.5, ['get', 'height']
          ],
          'fill-extrusion-base': [
            'interpolate', ['linear'], ['zoom'],
            14, 0,
            14.5, ['get', 'min_height']
          ],
          'fill-extrusion-opacity': 0.92,
          'fill-extrusion-vertical-gradient': true
        }
      }, labelLayerId);

      // 관광지 마커 (3D 위에 떠 있게)
      new mapboxgl.Marker({ color: '$markerColor' })
        .setLngLat([$lon, $lat])
        .setPopup(new mapboxgl.Popup({ offset: 25 }).setText('$name'))
        .addTo(map);
    });

    map.addControl(new mapboxgl.NavigationControl({ visualizePitch: true }), 'top-right');
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final visited = spot.visited;
    final color = visited ? spot.markerColor : const Color(0xFF1FAA8C);

    return Scaffold(
      backgroundColor: const Color(0xFFEDE9E1),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF1FAA8C)),
            ),
          _buildTopBar(),
          _buildBottomCard(color, visited),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            _circleButton(Icons.arrow_back, () => Navigator.of(context).pop()),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: widget.spot.markerColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.spot.markerIcon,
                        color: widget.spot.markerColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.spot.visited ? widget.spot.name : '미발견 장소',
                        style: const TextStyle(
                          fontFamily: 'Workbench',
                          fontSize: 16,
                          color: Color(0xFF2E2B2A),
                          letterSpacing: 0.8,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF2E2B2A)),
        ),
      ),
    );
  }

  Widget _buildBottomCard(Color color, bool visited) {
    final description = widget.spot.description ?? '관광지 정보';
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF54514D),
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (visited)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: color),
                          const SizedBox(width: 4),
                          Text(
                            '완료',
                            style: TextStyle(
                              fontFamily: 'Workbench',
                              color: color,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (visited || !widget.isWithinRadius)
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onCheckIn?.call();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FAA8C),
                    disabledBackgroundColor: const Color(0xFFC9C5BB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                  label: Text(
                    visited
                        ? '이미 인증한 장소'
                        : widget.isWithinRadius
                            ? '여기서 인증하기'
                            : '근처에 가야 인증 가능',
                    style: const TextStyle(
                      fontFamily: 'Workbench',
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
