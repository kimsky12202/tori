import 'package:flutter/material.dart';

import '../services/auth_api.dart';
import '../services/push_notification_service.dart';
import 'friends_page.dart';
import 'login/login_page.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) {
      return;
    }

    final bool shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('로그아웃'),
              content: const Text('이 기기에서 로그아웃할까요?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('로그아웃'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    await PushNotificationService.instance.deactivateCurrentDeviceToken();
    await AuthApi.clearSessionAndStorage();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (BuildContext context) => const LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color titleColor = Color(0xFF2E2B2A);
    const Color subtleTextColor = Color(0xFF7A756D);
    const Color dangerColor = Color(0xFFA14040);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1EA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: titleColor),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Text(
                '현재 기기에서 자동 로그인 상태가 유지됩니다.\n원하면 아래 버튼으로 로그아웃할 수 있습니다.',
                style: TextStyle(color: subtleTextColor, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.people_alt_outlined,
                  color: titleColor,
                ),
                title: const Text(
                  '친구 관리',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  '친구 검색, 요청 확인, 친구 목록 보기',
                  style: TextStyle(color: subtleTextColor, fontSize: 13),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: subtleTextColor,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => const FriendsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoggingOut ? null : _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(_isLoggingOut ? '로그아웃 중...' : '로그아웃'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
