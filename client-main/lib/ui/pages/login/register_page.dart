import 'package:flutter/material.dart';
import '../../services/auth_api.dart';
import '../../design/tori_theme.dart';
import '../../design/system/tori_widgets.dart';
import '../../design/layer/cloud_layer.dart';
import '../../design/layer/hanok_layer.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController =
      TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final AuthApi _authApi = AuthApi();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _passwordConfirmController.text.isEmpty ||
        _nicknameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력해주세요.')));
      return;
    }

    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 8자리 이상이어야 합니다.')));
      return;
    }

    if (_passwordController.text != _passwordConfirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호와 비밀번호 확인이 일치하지 않습니다.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authApi.register(
        email: _emailController.text.trim(),
        username: _nicknameController.text.trim(),
        password: _passwordController.text,
        passwordConfirm: _passwordConfirmController.text,
      );

      if (!mounted) {
        return;
      }

      _showSnackBar('회원가입이 완료되었습니다. 이메일 인증 후 로그인해주세요.');
      Navigator.pop(context);
    } on AuthApiException catch (e) {
      if (!mounted) {
        return;
      }

      _showSnackBar(e.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ToriColors.sky,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const HanokLayer(progress: 1.0),
          const CloudLayer(progress: 1.0),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 뒤로가기
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),

                  Text(
                    'TORI CAPSULE',
                    textAlign: TextAlign.center,
                    style: ToriText.logo.copyWith(color: ToriColors.logoLogin),
                  ),
                  const SizedBox(height: 30),

                  ToriField(
                    label: '이메일',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 7),
                  ToriField(
                    label: '비밀번호',
                    controller: _passwordController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 7),
                  ToriField(
                    label: '비밀번호\n 확인',
                    controller: _passwordConfirmController,
                    isPassword: true,
                  ),
                  const SizedBox(height: 7),
                  ToriField(label: '닉네임', controller: _nicknameController),

                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 80),
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
                        label: '가입하기',
                        onPressed: _isLoading ? null : _handleRegister,
                        isLoading: _isLoading,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}