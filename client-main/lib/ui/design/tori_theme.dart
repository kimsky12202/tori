import 'package:flutter/material.dart';

/// 토리 캡슐 디자인 토큰.
class ToriColors {
  ToriColors._();

  // 배경
  static const Color sky = Color(0xFFADD9F4);

  // 입력 필드
  static const Color fieldFill = Color(0xD4FFFFFF); // white 83%
  static const Color fieldBorder = Color(0xFF6FC8FF);
  static const Color fieldBorderLight = Color(0xFF6FBEFF);

  // 텍스트
  static const Color textPrimary = Color(0xFF2A2A2A);
  static const Color textBlack = Color(0xFF090909);
  static const Color textHint = Color(0xFFA8A398);

  // 로고
  static const Color logoSplash = Color(0xFFEDD6D6); // 스플래시: 핑크톤
  static const Color logoLogin = Colors.white;       // 로그인: 흰색

  // 소셜
  static const Color kakaoYellow = Color(0xFFFEE500);
  static const Color kakaoText = Color(0xFF3C1E1E);
}

class ToriFonts {
  ToriFonts._();
  static const String workbench = 'Workbench';
}

class ToriText {
  ToriText._();

  static const TextStyle logo = TextStyle(
    fontFamily: ToriFonts.workbench,
    fontSize: 20,
    fontWeight: FontWeight.w400,
    letterSpacing: 4.4,
    shadows: <Shadow>[
      Shadow(offset: Offset(0, 4), blurRadius: 4, color: Color(0x40000000)),
    ],
  );

  static const TextStyle pageTitle = TextStyle(
    fontFamily: ToriFonts.workbench,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.25,
    color: Colors.black,
  );

  static const TextStyle fieldLabel = TextStyle(
    fontFamily: ToriFonts.workbench,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.8,
    color: Colors.black,
  );

  static const TextStyle button = TextStyle(
    fontFamily: ToriFonts.workbench,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: ToriColors.textPrimary,
    letterSpacing: 1.8,
  );

  static const TextStyle small = TextStyle(
    fontFamily: ToriFonts.workbench,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    color: ToriColors.textBlack,
  );
}