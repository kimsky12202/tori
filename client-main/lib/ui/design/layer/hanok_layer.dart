import 'dart:ui';
import 'package:flutter/material.dart';
import '../system/design_canvas.dart';

/// 한옥 배경 레이어.
///
/// progress 0.0 → 1.0 사이에서 위치가 보간됨.
/// - 0.0 (스플래시): 피그마 top: 165
/// - 1.0 (로그인): 피그마 top: 188
class HanokLayer extends StatelessWidget {
  const HanokLayer({super.key, required this.progress});

  /// 0.0 = 스플래시, 1.0 = 로그인
  final double progress;

  // 피그마 좌표 (배경1.png: 480x706)
  static const double _splashTop = 165;
  static const double _loginTop = 500;
  static const double _left = -41;
  static const double _width = 480;
  static const double _height = 706;

  @override
  Widget build(BuildContext context) {
    return DesignCanvas(
      builder: (BuildContext context, DesignCanvasMetrics canvas) {
        final double top = lerpDouble(_splashTop, _loginTop, progress)!;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: canvas.dx(_left),
              top: canvas.dy(top),
              width: canvas.width(_width),
              height: canvas.height(_height),
              child: Image.asset(
                'assets/images/auth/background.png',
                fit: BoxFit.fill,
              ),
            ),
          ],
        );
      },
    );
  }
}