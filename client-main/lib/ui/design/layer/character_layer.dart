import 'package:flutter/material.dart';
import '../system/design_canvas.dart';

/// 캐릭터 레이어.
///
/// progress 0.0~0.5: 완전 불투명
/// progress 0.5~1.0: 페이드 아웃
class CharacterLayer extends StatelessWidget {
  const CharacterLayer({super.key, required this.progress});

  final double progress;

  // 피그마 좌표 (캐릭터.png: 348x269, 스플래시 기준)
  static const double _left = 31;
  static const double _top = 605;
  static const double _width = 348;
  static const double _height = 269;

  @override
  Widget build(BuildContext context) {
    // progress 0.5 이후부터 페이드 아웃
    final double opacity = (1.0 - ((progress - 0.5) / 0.5)).clamp(0.0, 1.0);

    if (opacity == 0) {
      return const SizedBox.shrink();
    }

    return DesignCanvas(
      builder: (BuildContext context, DesignCanvasMetrics canvas) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Positioned(
              left: canvas.dx(_left),
              top: canvas.dy(_top),
              width: canvas.width(_width),
              height: canvas.height(_height),
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  'assets/images/auth/character.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}