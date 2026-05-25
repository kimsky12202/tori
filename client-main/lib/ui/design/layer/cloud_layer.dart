import 'dart:ui';
import 'package:flutter/material.dart';
import '../system/design_canvas.dart';

/// 구름 레이어 (5개).
///
/// 각 구름의 스플래시 / 로그인 좌표를 피그마 그대로 보관하고
/// progress에 따라 보간.
class CloudLayer extends StatelessWidget {
  const CloudLayer({super.key, required this.progress});

  final double progress;

  // 피그마 좌표 (스플래시 → 로그인)
  // 각 항목: (asset, left, splashTop, loginTop, width, height)
  static const List<_CloudSpec> _clouds = <_CloudSpec>[
    // cloud1: 큰 구름 좌측
    _CloudSpec(
      asset: 'cloud1',
      left: -78,
      splashTop: 0,
      loginTop: -53,
      width: 310,
      height: 113,
    ),
    // cloud4: 작은 구름 중앙 (피그마 109x56)
    _CloudSpec(
      asset: 'cloud4',
      left: -32,
      splashTop: 149,
      loginTop: 96,
      width: 109,
      height: 56,
    ),
    // cloud3: 작은 구름 중앙 우측 (피그마 69x35)
    _CloudSpec(
      asset: 'cloud3',
      left: 136,
      splashTop: 149,
      loginTop: 96,
      width: 69,
      height: 35,
    ),
    // cloud2: 우측 상단
    _CloudSpec(
      asset: 'cloud2',
      left: 318.41,
      splashTop: 56,
      loginTop: 3,
      width: 121.45,
      height: 61.63,
    ),
    // cloud5: 우측 (회전된 큰 구름)
    _CloudSpec(
      asset: 'cloud5',
      left: 200,
      splashTop: 100,
      loginTop: 50,
      width: 220,
      height: 80,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DesignCanvas(
      builder: (BuildContext context, DesignCanvasMetrics canvas) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: _clouds.map((_CloudSpec spec) {
            final double top =
                lerpDouble(spec.splashTop, spec.loginTop, progress)!;

            Widget child = Image.asset(
              'assets/images/auth/${spec.asset}.png',
              fit: BoxFit.fill,
            );

            if (spec.rotateZ != 0) {
              child = Transform.rotate(angle: spec.rotateZ, child: child);
            }

            return Positioned(
              left: canvas.dx(spec.left),
              top: canvas.dy(top),
              width: canvas.width(spec.width),
              height: canvas.height(spec.height),
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

class _CloudSpec {
  const _CloudSpec({
    required this.asset,
    required this.left,
    required this.splashTop,
    required this.loginTop,
    required this.width,
    required this.height,
    this.rotateZ = 0,
  });

  final String asset;
  final double left;
  final double splashTop;
  final double loginTop;
  final double width;
  final double height;
  final double rotateZ;
}