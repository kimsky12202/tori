import 'package:flutter/material.dart';

/// Unity 통합이 잠시 비활성화된 상태의 placeholder 화면.
/// 추후 Unity export 가 안정화되면 원본 AR 화면 복원 예정.
class ArScreen extends StatelessWidget {
  const ArScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2E2B2A)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.view_in_ar_outlined,
                size: 64,
                color: Color(0xFFA14040),
              ),
              const SizedBox(height: 16),
              const Text(
                'AR 기능 준비 중',
                style: TextStyle(
                  fontFamily: 'Workbench',
                  fontSize: 20,
                  letterSpacing: 1.0,
                  color: Color(0xFF2E2B2A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AR 화면은 곧 다시 열려요.\n지금은 캡슐 등록과 GPS 인증을 이용해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7A756D),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA14040),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '돌아가기',
                  style: TextStyle(
                    fontFamily: 'Workbench',
                    color: Colors.white,
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
