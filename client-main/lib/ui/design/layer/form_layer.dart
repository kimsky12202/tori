import 'dart:ui';
import 'package:flutter/material.dart';
import '../tori_theme.dart';
import '../system/design_canvas.dart';
import '../system/tori_widgets.dart';

/// 로고 + 로그인 폼 레이어.
///
/// - TORI CAPSULE 로고: 스플래시(top: 428, 핑크) → 로그인(top: 216, 흰색)
/// - LOGIN 텍스트: progress >= 0.5에서 페이드 인
/// - 입력 필드/버튼: progress >= 0.5에서 페이드 인
class FormLayer extends StatelessWidget {
  const FormLayer({
    super.key,
    required this.progress,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.onResendVerification,
    required this.onKakaoLogin,
    required this.onGoogleLogin,
    required this.onGoRegister,
    required this.onFindId,
    required this.isLoading,
    required this.isResendingVerification,
    required this.isSocialLoading,
    required this.activeSocialProvider,
  });

  final double progress;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onResendVerification;
  final VoidCallback onKakaoLogin;
  final VoidCallback onGoogleLogin;
  final VoidCallback onGoRegister;
  final VoidCallback onFindId;
  final bool isLoading;
  final bool isResendingVerification;
  final bool isSocialLoading;
  final String? activeSocialProvider;

  // 로고 위치 (스플래시 → 로그인)
  static const double _logoSplashTop = 428;
  static const double _logoLoginTop = 216;

  // 로그인 폼 영역 (피그마 좌표)
  static const double _formLeft = 29;
  static const double _formRight = 29;

  // LOGIN 텍스트
  static const double _loginTextTop = 266;

  // 입력 필드 (각 41px, 사이 7px 간격으로 시작)
  static const double _emailFieldTop = 305;
  static const double _passwordFieldTop = 353;

  // 로그인 버튼
  static const double _loginButtonTop = 405;

  // 보조 링크 (회원가입 | 아이디찾기 | 비밀번호찾기)
  static const double _auxLinkTop = 455;

  // 소셜 버튼들
  static const double _kakaoButtonTop = 510;
  static const double _googleButtonTop = 560;

  @override
  Widget build(BuildContext context) {
    // 로그인 폼은 progress 0.5 이후부터 보임
    final double formOpacity = ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

    return DesignCanvas(
      builder: (BuildContext context, DesignCanvasMetrics canvas) {
        final double formWidth =
            DesignCanvasSize.width - _formLeft - _formRight;

        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            // ── 1. TORI CAPSULE 로고 (항상 보임, 위치만 변함)
            _buildLogo(canvas),

            // ── 2. 로그인 폼 (progress 0.5 이후 페이드 인)
            if (formOpacity > 0) ...<Widget>[
              // LOGIN 텍스트
              _buildLoginText(canvas, formOpacity, formWidth),

              // 이메일 입력
              _buildField(
                canvas: canvas,
                top: _emailFieldTop,
                width: formWidth,
                opacity: formOpacity,
                child: ToriField(
                  label: '이메일',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),

              // 비밀번호 입력
              _buildField(
                canvas: canvas,
                top: _passwordFieldTop,
                width: formWidth,
                opacity: formOpacity,
                child: ToriField(
                  label: '비밀번호',
                  controller: passwordController,
                  isPassword: true,
                ),
              ),

              // 로그인 버튼 (둥근 박스 안에 텍스트)
              Positioned(
                left: canvas.dx(_formLeft + 80),       // 좌우 여백 추가해서 박스 작게
                top: canvas.dy(_loginButtonTop),
                width: canvas.width(formWidth - 160),  // 박스를 좁게
                child: Opacity(
                  opacity: formOpacity,
                  child: Container(
                    height: 36,
                    decoration: ShapeDecoration(
                      color: ToriColors.fieldFill,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(width: 2, color: ToriColors.fieldBorder),
                        borderRadius: BorderRadius.circular(200),
                      ),
                    ),
                    child: ToriPrimaryButton(
                      label: '로그인',
                      onPressed: isLoading ? null : onLogin,
                      isLoading: isLoading,
                    ),
                  ),
                ),
              ),

              // 보조 링크
              _buildField(
                canvas: canvas,
                top: _auxLinkTop,
                width: formWidth,
                opacity: formOpacity,
                child: _buildAuxLinks(),
              ),

              // 카카오 버튼
              _buildField(
                canvas: canvas,
                top: _kakaoButtonTop,
                width: formWidth,
                opacity: formOpacity,
                child: ToriSocialButton(
                  bgColor: ToriColors.kakaoYellow,
                  fgColor: ToriColors.kakaoText,
                  label: activeSocialProvider == 'kakao'
                      ? '카카오 로그인 진행 중...'
                      : '카카오톡아이디로 로그인',
                  onPressed: onKakaoLogin,
                  isEnabled: !isLoading &&
                      !isResendingVerification &&
                      (!isSocialLoading || activeSocialProvider == 'kakao'),
                ),
              ),

              // 구글 버튼
              _buildField(
                canvas: canvas,
                top: _googleButtonTop,
                width: formWidth,
                opacity: formOpacity,
                child: ToriSocialButton(
                  bgColor: Colors.white,
                  fgColor: ToriColors.textPrimary,
                  label: activeSocialProvider == 'google'
                      ? 'Google 로그인 진행 중...'
                      : '구글아이디로 로그인',
                  onPressed: onGoogleLogin,
                  isEnabled: !isLoading &&
                      !isResendingVerification &&
                      (!isSocialLoading || activeSocialProvider == 'google'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildLogo(DesignCanvasMetrics canvas) {
    final double top = lerpDouble(_logoSplashTop, _logoLoginTop, progress)!;
    final Color color =
        Color.lerp(ToriColors.logoSplash, ToriColors.logoLogin, progress)!;

    return Positioned(
      left: 0,
      right: 0,
      top: canvas.dy(top),
      child: Text(
        'TORI CAPSULE',
        textAlign: TextAlign.center,
        style: ToriText.logo.copyWith(color: color),
      ),
    );
  }

  Widget _buildLoginText(
    DesignCanvasMetrics canvas,
    double opacity,
    double formWidth,
  ) {
    return Positioned(
      left: canvas.dx(_formLeft),
      top: canvas.dy(_loginTextTop),
      width: canvas.width(formWidth),
      child: Opacity(
        opacity: opacity,
        child: const Text(
          'LOGIN',
          textAlign: TextAlign.center,
          style: ToriText.pageTitle,
        ),
      ),
    );
  }

  Widget _buildField({
    required DesignCanvasMetrics canvas,
    required double top,
    required double width,
    required double opacity,
    required Widget child,
  }) {
    return Positioned(
      left: canvas.dx(_formLeft),
      top: canvas.dy(top),
      width: canvas.width(width),
      child: Opacity(opacity: opacity, child: child),
    );
  }

  Widget _buildAuxLinks() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: onGoRegister,
          child: const Text('회원가입', style: ToriText.small),
        ),
        const Text('  |   ', style: ToriText.small),
        GestureDetector(
          onTap: onFindId,
          child: const Text('아이디 찾기', style: ToriText.small),
        ),
        const Text('   |  ', style: ToriText.small),
        GestureDetector(
          onTap: isResendingVerification ? null : onResendVerification,
          child: Text(
            isResendingVerification ? '메일 보내는 중...' : '비밀번호 찾기',
            style: ToriText.small,
          ),
        ),
      ],
    );
  }
}