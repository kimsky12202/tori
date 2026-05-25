import 'package:flutter/material.dart';
import '../../design/layer/character_layer.dart';
import '../../design/layer/cloud_layer.dart';
import '../../design/layer/form_layer.dart';
import '../../design/layer/hanok_layer.dart';
import '../../design/tori_theme.dart';
import '../../services/auth_api.dart';
import '../../services/push_notification_service.dart';
import '../main_tab_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthApi _authApi = AuthApi();
  late final AnimationController _animController; // 애니메이션 컨트롤러 변수
  bool _isLoading = false;
  bool _isResendingVerification = false;
  bool _isSocialLoading = false;
  String? _activeSocialProvider;
  Set<String> _availableSocialProviders = <String>{};

  //애니메이션 타이밍
  static const Duration _splashHoldDuration = Duration(milliseconds: 1500);
  static const Duration _transitionDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 이미지 미리 로드
    precacheImage(
      const AssetImage('assets/images/auth/background.png'),
      context,
    );
    precacheImage(
      const AssetImage('assets/images/auth/character.png'),
      context,
    );
    for (int i = 1; i <= 5; i++) {
      precacheImage(AssetImage('assets/images/auth/cloud$i.png'), context);
    }
  }

  Future<void> _bootstrap() async {
    final bool sessionRestored = await AuthApi.tryRestoreSession();
    if (!mounted) return;

    if (sessionRestored) {
      await PushNotificationService.instance.syncTokenWithServer();

      // 이미 로그인 → 스플래시만 잠깐 보여주고 메인 탭으로
      await Future<void>.delayed(_splashHoldDuration);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(builder: (_) => const MainTabPage()),
      );
      return;
    }

    // 미로그인 → 스플래시 잠깐 보여준 뒤 전환 애니메이션 시작
    await Future<void>.delayed(_splashHoldDuration);
    if (!mounted) return;
    _animController.forward();

    _loadSocialProviders();
  }

  Future<void> _loadSocialProviders() async {
    try {
      final Set<String> providers = await _authApi
          .listAvailableSocialProviders();
      if (!mounted) {
        return;
      }

      setState(() {
        _availableSocialProviders = providers;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _availableSocialProviders = <String>{};
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final LoginResult loginResult = await _authApi.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await AuthApi.persistLoginResult(loginResult);
      await PushNotificationService.instance.syncTokenWithServer();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainTabPage()),
      );
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendVerification() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 받을 이메일을 먼저 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isResendingVerification = true;
    });

    try {
      await _authApi.requestVerification(email: _emailController.text.trim());

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 다시 보냈습니다. 메일함을 확인해주세요.')),
      );
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 메일 재발송 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) {
        setState(() {
          _isResendingVerification = false;
        });
      }
    }
  }

  Future<void> _handleSocialLogin({
    required String providerId,
    required String providerLabel,
  }) async {
    if (_isSocialLoading) {
      return;
    }

    if (!_availableSocialProviders.contains(providerId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$providerLabel 로그인은 아직 서버에 연결되지 않았습니다. PocketBase 관리자 화면에서 provider 설정을 먼저 완료해주세요.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSocialLoading = true;
      _activeSocialProvider = providerId;
    });

    try {
      final LoginResult loginResult = await _authApi.loginWithSocial(
        provider: providerId,
      );
      await AuthApi.persistLoginResult(loginResult);
      await PushNotificationService.instance.syncTokenWithServer();

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainTabPage()),
      );
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$providerLabel 로그인 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSocialLoading = false;
          _activeSocialProvider = null;
        });
      }
    }
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
    );
  }

  void _handleFindId() {
    _showSnackBar('아이디 찾기는 준비 중입니다.');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ToriColors.sky,
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _animController,
        builder: (BuildContext context, _) {
          final double progress = _animController.value;

          return Stack(
            children: <Widget>[
              HanokLayer(progress: progress),
              CloudLayer(progress: progress),
              CharacterLayer(progress: progress),
              FormLayer(
                progress: progress,
                emailController: _emailController,
                passwordController: _passwordController,
                onLogin: _handleLogin,
                onResendVerification: _handleResendVerification,
                onKakaoLogin: () => _handleSocialLogin(
                  providerId: 'kakao',
                  providerLabel: '카카오',
                ),
                onGoogleLogin: () => _handleSocialLogin(
                  providerId: 'google',
                  providerLabel: 'Google',
                ),
                onGoRegister: _goToRegister,
                onFindId: _handleFindId,
                isLoading: _isLoading,
                isResendingVerification: _isResendingVerification,
                isSocialLoading: _isSocialLoading,
                activeSocialProvider: _activeSocialProvider,
              ),
            ],
          );
        },
      ),
    );
  }
}
