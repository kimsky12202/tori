import 'package:flutter/material.dart';
import 'package:flutter_unity_widget/flutter_unity_widget.dart';
import 'package:geolocator/geolocator.dart';
import '../capsule/capsule_content_sheet.dart';
import '../../services/capsule_api.dart';

class CapsuleItem {
  final String id;
  final String name;
  final String imagePath;
  final IconData icon;
  final Color color;

  const CapsuleItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.icon,
    required this.color,
  });
}

const List<CapsuleItem> kAvailableCapsules = [
  CapsuleItem(
    id: 'default',
    name: '자계함',
    imagePath:'assets/images/capsule/3D/base/basic_cube.png',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFA14040),
  ),
];

enum _CapsuleState {
  scanning,
  idle, // 캡슐 미선택
  floating, // 공중에 떠있음
  falling, // 낙하 중
  burying, // 땅속으로 들어가는 중
  done, // 완료
}

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});

  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen> {
  UnityWidgetController? _unityController;
  DateTime? _lastTouchSent;
  Offset? _lastTouchPos;
  _CapsuleState _capsuleState = _CapsuleState.scanning;
  CapsuleItem _selectedCapsule = kAvailableCapsules.first;

  double? _pendingLat;
  double? _pendingLng;

  final _capsuleApi = CapsuleApi();
  String? _pendingCapsuleId;

  void _onUnityCreated(UnityWidgetController controller) {
    _unityController = controller;
    controller.postMessage('TimecapsuleManager', 'ResetAR', '');
  }

  // Unity → Flutter: 상태 변화 수신
  void _onUnityMessage(dynamic message) {
    if (!mounted) return;
    switch (message.toString()) {
      case 'FloorDetected':
        if (_capsuleState == _CapsuleState.scanning) {
          setState(() => _capsuleState = _CapsuleState.idle);
        }
        break;
      case 'Floating':
        setState(() => _capsuleState = _CapsuleState.floating);
        break;
      case 'Falling':
        setState(() => _capsuleState = _CapsuleState.falling);
        break;
      case 'Burying':
        setState(() => _capsuleState = _CapsuleState.burying);
        break;
      case 'BuryComplete':
        setState(() => _capsuleState = _CapsuleState.done);
        if (_pendingCapsuleId != null) {
          _capsuleApi.buryCapsule(capsuleId: _pendingCapsuleId!);
        }
        break;
    }
  }

  // Flutter → Unity: 캡슐 소환 명령
  void _spawnCapsule() {
    _unityController?.postMessage(
      'TimecapsuleManager',
      'SpawnCapsule',
      _selectedCapsule.id,
    );
    setState(() => _capsuleState = _CapsuleState.floating);
  }

  void _showCapsuleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '캡슐 선택',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...kAvailableCapsules.map((c) => _buildCapsuleCard(c)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showContentDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sheetController) => PrimaryScrollController(
          controller: sheetController,
          child: CapsuleContentSheet(
            onConfirm: (data) async {
              await _captureGPS();

              final id = await _capsuleApi.createCapsule(
                data: data,
                latitude: _pendingLat ?? 0,
                longitude: _pendingLng ?? 0,
                memberIds: data.friendIds,
              );

              _pendingCapsuleId = id;
              _spawnCapsule();
            },
          ),
        ),
      ),
    );
  }

  Future<void> _captureGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _pendingLat = position.latitude;
      _pendingLng = position.longitude;
    } catch (_) {}
  }

  Widget _buildCapsuleCard(CapsuleItem capsule) {
    final isSelected = capsule.id == _selectedCapsule.id;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() => _selectedCapsule = capsule);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? capsule.color.withValues(alpha: 0.2)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? capsule.color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  width: constraints.maxWidth * 0.6, // 부모 너비의 60%
                  height: constraints.maxWidth * 0.6, // 정사각형 비율 유지
                  child: Transform.scale(
                    scale: 3.5, // 💡 여기서 숫자를 조절하여 원하는 만큼 확대하세요! (예: 1.5 = 1.5배)
                    child: Image.asset(
                      capsule.imagePath,
                      fit: BoxFit.contain, // 이미지가 잘리지 않고 원본 비율을 유지하도록 복구
                      
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(capsule.icon, color: capsule.color, size: 48);
                      },
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  capsule.name,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (isSelected) ...[ // 선택되었을 때만 표시
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: capsule.color, size: 20),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Unity AR 뷰 (카메라 + AR + 타임캡슐 렌더링 담당)
          GestureDetector(
            onPanUpdate: _capsuleState == _CapsuleState.floating
                ? (details) {
                    final now = DateTime.now();
                    final pos = details.localPosition;

                    // Throttle: 16ms 미만이면 스킵
                    if (_lastTouchSent != null &&
                        now.difference(_lastTouchSent!).inMilliseconds < 16) {
                      return;
                    }

                    // Delta threshold: 3픽셀 미만 이동이면 스킵
                    if (_lastTouchPos != null) {
                      final dx = pos.dx - _lastTouchPos!.dx;
                      final dy = pos.dy - _lastTouchPos!.dy;
                      if (dx * dx + dy * dy < 9) return;
                    }

                    _lastTouchSent = now;
                    _lastTouchPos = pos;

                    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
                    final physicalX = pos.dx * pixelRatio;
                    final physicalY = pos.dy * pixelRatio;
                    final screenH =
                        MediaQuery.of(context).size.height * pixelRatio;
                    _unityController?.postMessage(
                      'TimecapsuleManager',
                      'OnFlutterTouch',
                      '$physicalX,${screenH - physicalY}',
                    );
                  }
                : null,
            onPanEnd:
                _capsuleState ==
                    _CapsuleState
                        .floating // ← 이 블록 추가
                ? (_) {
                    _lastTouchPos = null;
                    _lastTouchSent = null;
                    _unityController?.postMessage(
                      'TimecapsuleManager',
                      'OnFlutterTouchEnd',
                      '',
                    );
                    setState(() => _capsuleState = _CapsuleState.falling);
                  }
                : null,
            child: UnityWidget(
              onUnityCreated: _onUnityCreated,
              onUnityMessage: _onUnityMessage,
              fullscreen: false,
              useAndroidViewSurface: false,
            ),
          ),
          _buildTopBar(),
          _buildGuideText(),
          if (_capsuleState == _CapsuleState.done) _buildDoneOverlay(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideText() {
    final text = switch (_capsuleState) {
      _CapsuleState.scanning => '카메라를 바닥으로 향해 천천히 움직여주세요.',
      _CapsuleState.idle => '아래 캡슐 버튼을 눌러 선택하세요.',
      _CapsuleState.floating => '드래그하여 원하는 위치로 이동 후 손을 떼세요.',
      _CapsuleState.falling => '타임캡슐이 떨어지고 있습니다...',
      _CapsuleState.burying => '땅속으로 들어가고 있습니다...',
      _CapsuleState.done => '타임캡슐이 묻혔습니다!',
    };
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 64),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.extended(
                heroTag: 'capsule_select',
                onPressed:
                    (_capsuleState == _CapsuleState.idle ||
                        _capsuleState == _CapsuleState.floating)
                    ? _showCapsuleSelector
                    : null,
                backgroundColor: const Color(
                  0xFF1A1A1A,
                ).withValues(alpha: 0.85),
                icon: Icon(
                  _selectedCapsule.icon,
                  color: _selectedCapsule.color,
                ),
                label: Text(
                  _selectedCapsule.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              if (_capsuleState == _CapsuleState.idle) ...[
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'spawn',
                  onPressed: _showContentDialog,
                  backgroundColor: const Color(0xFFA14040),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFA14040), size: 56),
            const SizedBox(height: 12),
            const Text(
              '타임캡슐이 묻혔습니다!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA14040),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('완료', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
