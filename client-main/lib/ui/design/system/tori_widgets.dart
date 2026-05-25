import 'package:flutter/material.dart';
import '../tori_theme.dart';

/// 토리 입력 필드 — 좌측 라벨 + 세로 구분선 + 우측 입력.
class ToriField extends StatelessWidget {
  const ToriField({
    super.key,
    required this.label,
    required this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 41,
      decoration: ShapeDecoration(
        color: ToriColors.fieldFill,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 2, color: ToriColors.fieldBorder),
          borderRadius: BorderRadius.circular(200),
        ),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(width: 16),
          SizedBox(
            width: 66,
            child: Text(label, style: ToriText.fieldLabel),
          ),
          Container(width: 2, height: 25, color: ToriColors.fieldBorder),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: isPassword,
              keyboardType: keyboardType,
              readOnly: readOnly,
              onTap: onTap,
              style: const TextStyle(
                fontFamily: ToriFonts.workbench,
                fontSize: 13,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// 토리 메인 액션 버튼 (로그인 / 가입하기 등) — 픽셀톤 텍스트 버튼.
class ToriPrimaryButton extends StatelessWidget {
  const ToriPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: ToriColors.textPrimary,
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ToriColors.textPrimary,
                ),
              )
            : Text(label, style: ToriText.button),
      ),
    );
  }
}

/// 토리 소셜 로그인 버튼.
class ToriSocialButton extends StatelessWidget {
  const ToriSocialButton({
    super.key,
    required this.bgColor,
    required this.fgColor,
    required this.label,
    required this.onPressed,
    this.isEnabled = true,
  });

  final Color bgColor;
  final Color fgColor;
  final String label;
  final VoidCallback onPressed;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 41,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 2, color: ToriColors.fieldBorder),
            borderRadius: BorderRadius.circular(200),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: ToriFonts.workbench,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: fgColor,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}