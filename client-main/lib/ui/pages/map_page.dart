import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'ar/ar_screen.dart';
import 'capsule/capsule_content_sheet.dart';
import '../services/capsule_api.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _capsuleApi = CapsuleApi();
  bool _isCreatingCapsule = false;

  Future<(double, double)?> _captureGPS() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return (position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> _createCapsuleDirectly(CapsuleData data) async {
    if (_isCreatingCapsule) return;
    setState(() => _isCreatingCapsule = true);

    final coords = await _captureGPS();
    final latitude = coords?.$1 ?? 0;
    final longitude = coords?.$2 ?? 0;

    final capsuleId = await _capsuleApi.createCapsule(
      data: data,
      latitude: latitude,
      longitude: longitude,
      memberIds: data.friendIds,
    );

    bool isBuried = false;
    if (capsuleId != null) {
      isBuried = await _capsuleApi.buryCapsule(capsuleId: capsuleId);
    }

    if (!mounted) return;
    setState(() => _isCreatingCapsule = false);

    if (capsuleId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캡슐 생성에 실패했습니다.')));
      return;
    }

    if (!isBuried) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('캡슐은 생성됐지만 묻기 처리에 실패했습니다.')));
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('캡슐이 추가되었습니다.')));
  }

  void _showCapsuleCreateSheet() {
    if (_isCreatingCapsule) return;
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
          child: CapsuleContentSheet(onConfirm: _createCapsuleDirectly),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2E2B2A)),
      ),
      body: const Center(
        child: Text(
          '지도 화면',
          style: TextStyle(color: Color(0xFF2E2B2A), fontSize: 16),
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'quick_capsule_create',
            onPressed: _isCreatingCapsule ? null : _showCapsuleCreateSheet,
            backgroundColor: const Color(0xFF2E2B2A),
            icon: _isCreatingCapsule
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add, color: Colors.white),
            label: const Text('캡슐 추가', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'ar_enter',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ArScreen()),
              );
            },
            backgroundColor: const Color(0xFFA14040),
            child: const Icon(Icons.view_in_ar, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
