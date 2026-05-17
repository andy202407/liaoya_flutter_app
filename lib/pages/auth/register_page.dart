import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreed = false;

  // 实时校验错误
  String? _usernameError;
  String? _nicknameError;
  String? _passwordError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_validateUsername);
    _nicknameController.addListener(_validateNickname);
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validateConfirmPassword);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final u = _usernameController.text;
    final phonePattern = RegExp(r'1[3-9]\d{9}');
    final emailPattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

    setState(() {
      if (u.isEmpty) {
        _usernameError = null; // 空的时候不显示错误
      } else if (u.length < 6) {
        _usernameError = '用户名至少需要6个字符';
      } else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(u)) {
        _usernameError = '用户名只能包含字母和数字';
      } else if (RegExp(r'^\d+$').hasMatch(u)) {
        _usernameError = '用户名不能为纯数字';
      } else if (phonePattern.hasMatch(u)) {
        _usernameError = '用户名不能包含手机号码';
      } else if (emailPattern.hasMatch(u)) {
        _usernameError = '用户名不能包含邮箱地址';
      } else {
        _usernameError = null;
      }
    });
  }

  void _validateNickname() {
    final n = _nicknameController.text;
    final u = _usernameController.text;
    final phonePattern = RegExp(r'1[3-9]\d{9}');
    final emailPattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');

    setState(() {
      if (n.isEmpty) {
        _nicknameError = null;
      } else if (n.contains(' ')) {
        _nicknameError = '昵称不能包含空格';
      } else if (!RegExp(r'^[\u4e00-\u9fffa-zA-Z0-9]+$').hasMatch(n)) {
        _nicknameError = '昵称只能包含中文、英文和数字';
      } else if (n.toLowerCase() == u.toLowerCase() && u.isNotEmpty) {
        _nicknameError = '昵称不能与用户名相同';
      } else if (phonePattern.hasMatch(n)) {
        _nicknameError = '昵称不能包含手机号码';
      } else if (emailPattern.hasMatch(n)) {
        _nicknameError = '昵称不能包含邮箱地址';
      } else {
        _nicknameError = null;
      }
    });
  }

  void _validatePassword() {
    final p = _passwordController.text;
    setState(() {
      if (p.isEmpty) {
        _passwordError = null;
      } else if (p.length < 8) {
        _passwordError = '密码至少需要8个字符';
      } else {
        final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
        final hasLower = RegExp(r'[a-z]').hasMatch(p);
        final hasDigit = RegExp(r'[0-9]').hasMatch(p);
        final types = [hasUpper, hasLower, hasDigit].where((b) => b).length;
        if (types < 2) {
          _passwordError = '密码需包含大写字母、小写字母、数字中的至少两种';
        } else {
          _passwordError = null;
        }
      }
    });
    _validateConfirmPassword();
  }

  void _validateConfirmPassword() {
    final cp = _confirmPasswordController.text;
    final p = _passwordController.text;
    setState(() {
      if (cp.isEmpty) {
        _confirmError = null;
      } else if (cp != p) {
        _confirmError = '两次输入的密码不一致';
      } else {
        _confirmError = null;
      }
    });
  }

  bool get _isFormValid {
    final u = _usernameController.text;
    final n = _nicknameController.text;
    final p = _passwordController.text;
    final cp = _confirmPasswordController.text;
    return u.length >= 6 && n.isNotEmpty && p.length >= 8 && cp == p &&
        _usernameError == null && _nicknameError == null &&
        _passwordError == null && _confirmError == null && _agreed;
  }

  Future<void> _handleRegister() async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请检查表单填写是否正确')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
      _nicknameController.text.trim(),
    );

    if (success && mounted) {
      if (auth.isAuthenticated) {
        // 注册后自动登录成功，清除路由栈
        try { context.read<ConversationProvider>().reset(); } catch (_) {}
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('注册成功，请登录')),
        );
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else if (mounted && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部返回
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Iconsax.arrow_left, color: Colors.white),
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Text('创建账户', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 8),
                      const Text('填写以下信息完成注册', style: TextStyle(fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 32),

                      // 表单卡片
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildField(_usernameController, '用户名', Iconsax.profile_circle, error: _usernameError, hint: '6位以上字母和数字'),
                            const SizedBox(height: 16),
                            _buildField(_nicknameController, '昵称', Iconsax.user_tag, error: _nicknameError, hint: '中文、英文或数字'),
                            const SizedBox(height: 16),
                            _buildField(_passwordController, '密码', Iconsax.lock, error: _passwordError, hint: '8位以上，含大小写或数字', obscure: _obscurePassword, toggleObscure: () => setState(() => _obscurePassword = !_obscurePassword)),
                            const SizedBox(height: 16),
                            _buildField(_confirmPasswordController, '确认密码', Iconsax.lock, error: _confirmError, hint: '再次输入密码', obscure: _obscureConfirm, toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                            const SizedBox(height: 20),

                            // 协议
                            Row(
                              children: [
                                SizedBox(
                                  width: 20, height: 20,
                                  child: Checkbox(
                                    value: _agreed,
                                    onChanged: (v) => setState(() => _agreed = v ?? false),
                                    activeColor: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _agreed = !_agreed),
                                    child: const Text('我已阅读并同意《用户协议》和《隐私政策》', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: (auth.isLoading || !_isFormValid) ? null : _handleRegister,
                                child: auth.isLoading
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Text('注册'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {
    String? error, String? hint, bool obscure = false, VoidCallback? toggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint ?? label,
            prefixIcon: Icon(icon),
            suffixIcon: toggleObscure != null
                ? IconButton(icon: Icon(obscure ? Iconsax.eye_slash : Iconsax.eye), onPressed: toggleObscure)
                : null,
            errorText: error,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}
