import 'package:flutter/material.dart';

/// 피그마 디자인 캔버스 기준 크기.
///
/// 모든 디자인은 이 캔버스 안의 좌표로 작성되고,
/// [DesignCanvas]가 실제 화면 크기에 맞게 스케일·변환한다.
class DesignCanvasSize {
  DesignCanvasSize._();

  static const double width = 402;
  static const double height = 874;
  static const double aspectRatio = width / height; // ≈ 0.46
}

/// 디자인 캔버스 안의 좌표를 실제 화면 좌표로 변환해주는 위젯.
///
/// 사용 예:
/// ```dart
/// DesignCanvas(
///   builder: (context, canvas) {
///     return Stack(
///       children: [
///         Positioned(
///           left: canvas.dx(29),    // 피그마 left: 29
///           top: canvas.dy(305),    // 피그마 top: 305
///           width: canvas.dx(338),  // 피그마 width: 338
///           height: canvas.dy(41),  // 피그마 height: 41
///           child: ...,
///         ),
///       ],
///     );
///   },
/// )
/// ```
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.builder,
    this.fit = DesignFit.coverWidth,
  });

  final Widget Function(BuildContext context, DesignCanvasMetrics canvas) builder;
  final DesignFit fit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final DesignCanvasMetrics canvas = DesignCanvasMetrics(
          screenWidth: constraints.maxWidth,
          screenHeight: constraints.maxHeight,
          fit: fit,
        );

        return builder(context, canvas);
      },
    );
  }
}

/// 캔버스 좌표 → 화면 좌표 변환을 담당하는 객체.
class DesignCanvasMetrics {
  DesignCanvasMetrics({
    required this.screenWidth,
    required this.screenHeight,
    this.fit = DesignFit.coverWidth,
  });

  final double screenWidth;
  final double screenHeight;
  final DesignFit fit;

  /// 캔버스 가로 1pt당 실제 화면 픽셀 수.
  double get scaleX {
    switch (fit) {
      case DesignFit.coverWidth:
        return screenWidth / DesignCanvasSize.width;
      case DesignFit.coverHeight:
        return screenHeight / DesignCanvasSize.height;
      case DesignFit.contain:
        return _containScale;
      case DesignFit.stretch:
        return screenWidth / DesignCanvasSize.width;
    }
  }

  /// 캔버스 세로 1pt당 실제 화면 픽셀 수.
  double get scaleY {
    switch (fit) {
      case DesignFit.coverWidth:
        return screenWidth / DesignCanvasSize.width;
      case DesignFit.coverHeight:
        return screenHeight / DesignCanvasSize.height;
      case DesignFit.contain:
        return _containScale;
      case DesignFit.stretch:
        return screenHeight / DesignCanvasSize.height;
    }
  }

  /// `contain` 모드일 때의 스케일.
  /// 캔버스가 화면에 완전히 들어갈 수 있는 최대 스케일.
  double get _containScale {
    final double scaleByWidth = screenWidth / DesignCanvasSize.width;
    final double scaleByHeight = screenHeight / DesignCanvasSize.height;
    return scaleByWidth < scaleByHeight ? scaleByWidth : scaleByHeight;
  }

  /// 캔버스 X 좌표 → 화면 X 좌표.
  double dx(double designX) => designX * scaleX;

  /// 캔버스 Y 좌표 → 화면 Y 좌표.
  double dy(double designY) => designY * scaleY;

  /// 캔버스에서 화면 너비 비율로 변환된 width 값.
  double width(double designWidth) => designWidth * scaleX;

  /// 캔버스에서 화면 높이 비율로 변환된 height 값.
  double height(double designHeight) => designHeight * scaleY;

  /// 캔버스 폰트 크기 → 화면 폰트 크기.
  /// 가로 스케일만 사용해서 일관성 유지.
  double fontSize(double designFontSize) => designFontSize * scaleX;
}

/// 캔버스를 화면에 맞추는 방식.
enum DesignFit {
  /// 화면 너비를 기준으로 캔버스를 채움. **세로 디자인 권장.**
  /// 캔버스 세로가 화면보다 짧으면 아래에 여백, 길면 일부 잘림.
  coverWidth,

  /// 화면 높이를 기준으로 캔버스를 채움. 가로 디자인용.
  coverHeight,

  /// 캔버스가 화면에 완전히 들어가도록 fit. 여백 발생 가능.
  contain,

  /// 가로·세로 각각 늘림. 비율 깨질 수 있음.
  stretch,
}