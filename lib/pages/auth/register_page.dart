import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../theme/app_colors.dart';

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
  final _usernameFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreed = false;

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
    _usernameFocus.addListener(() => setState(() {}));
    _nicknameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameFocus.dispose();
    _nicknameFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _validateUsername() {
    final u = _usernameController.text;
    final phonePattern = RegExp(r'1[3-9]\d{9}');
    final emailPattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    setState(() {
      if (u.isEmpty) { _usernameError = null; }
      else if (u.length < 6) { _usernameError = '用户名至少需要6个字符'; }
      else if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(u)) { _usernameError = '用户名只能包含字母和数字'; }
      else if (RegExp(r'^\d+$').hasMatch(u)) { _usernameError = '用户名不能为纯数字'; }
      else if (phonePattern.hasMatch(u)) { _usernameError = '用户名不能包含手机号码'; }
      else if (emailPattern.hasMatch(u)) { _usernameError = '用户名不能包含邮箱地址'; }
      else { _usernameError = null; }
    });
  }

  void _validateNickname() {
    final n = _nicknameController.text;
    final u = _usernameController.text;
    final phonePattern = RegExp(r'1[3-9]\d{9}');
    final emailPattern = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    setState(() {
      if (n.isEmpty) { _nicknameError = null; }
      else if (n.contains(' ')) { _nicknameError = '昵称不能包含空格'; }
      else if (!RegExp(r'^[\u4e00-\u9fffa-zA-Z0-9]+$').hasMatch(n)) { _nicknameError = '昵称只能包含中文、英文和数字'; }
      else if (n.toLowerCase() == u.toLowerCase() && u.isNotEmpty) { _nicknameError = '昵称不能与用户名相同'; }
      else if (phonePattern.hasMatch(n)) { _nicknameError = '昵称不能包含手机号码'; }
      else if (emailPattern.hasMatch(n)) { _nicknameError = '昵称不能包含邮箱地址'; }
      else { _nicknameError = null; }
    });
  }

  void _validatePassword() {
    final p = _passwordController.text;
    setState(() {
      if (p.isEmpty) { _passwordError = null; }
      else if (p.length < 8) { _passwordError = '密码至少需要8个字符'; }
      else {
        final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
        final hasLower = RegExp(r'[a-z]').hasMatch(p);
        final hasDigit = RegExp(r'[0-9]').hasMatch(p);
        final types = [hasUpper, hasLower, hasDigit].where((b) => b).length;
        if (types < 2) { _passwordError = '需包含大写、小写、数字中至少两种'; }
        else { _passwordError = null; }
      }
    });
    _validateConfirmPassword();
  }

  void _validateConfirmPassword() {
    final cp = _confirmPasswordController.text;
    final p = _passwordController.text;
    setState(() {
      if (cp.isEmpty) { _confirmError = null; }
      else if (cp != p) { _confirmError = '两次输入的密码不一致'; }
      else { _confirmError = null; }
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
      _showMsg('请检查表单填写是否正确');
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
      _nicknameController.text.trim(),
    );

    if (success && mounted) {
      if (auth.isAuthenticated) {
        try { context.read<ConversationProvider>().reset(); } catch (_) {}
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        _showMsg('注册成功，请登录');
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } else if (mounted && auth.error != null) {
      HapticFeedback.heavyImpact();
      _showMsg(auth.error!);
    }
  }

  void _showMsg(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提示'),
        content: Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg)),
        actions: [CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(CupertinoIcons.back, size: 24),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                '创建账户',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightText),
              ),
              const SizedBox(height: 6),
              Text(
                '填写以下信息完成注册',
                style: TextStyle(fontSize: 14, color: AppColors.systemGray),
              ),
              const SizedBox(height: 36),

              _buildTextField(
                controller: _usernameController,
                focusNode: _usernameFocus,
                placeholder: '6位以上字母和数字',
                icon: CupertinoIcons.person,
                isDark: isDark,
                error: _usernameError,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _nicknameFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _nicknameController,
                focusNode: _nicknameFocus,
                placeholder: '中文、英文或数字',
                icon: CupertinoIcons.textformat,
                isDark: isDark,
                error: _nicknameError,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                placeholder: '8位以上，含大小写或数字',
                icon: CupertinoIcons.lock,
                isDark: isDark,
                error: _passwordError,
                obscure: _obscurePassword,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _confirmFocus.requestFocus(),
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                      size: 20, color: AppColors.systemGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _buildTextField(
                controller: _confirmPasswordController,
                focusNode: _confirmFocus,
                placeholder: '再次输入密码',
                icon: CupertinoIcons.lock,
                isDark: isDark,
                error: _confirmError,
                obscure: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _obscureConfirm ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                      size: 20, color: AppColors.systemGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 协议
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _agreed = !_agreed);
                },
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _agreed ? AppColors.primary : Colors.transparent,
                        border: _agreed ? null : Border.all(color: AppColors.systemGray3, width: 1),
                        shape: BoxShape.circle,
                      ),
                      child: _agreed ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '我已阅读并同意《用户协议》和《隐私政策》',
                        style: TextStyle(fontSize: 13, color: AppColors.systemGray),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (auth.isLoading || !_isFormValid) ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                    disabledForegroundColor: Colors.white60,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('注册', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required IconData icon,
    required bool isDark,
    String? error,
    bool obscure = false,
    Widget? suffix,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: hasError
                    ? AppColors.error
                    : isFocused
                        ? AppColors.primary
                        : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
                width: (isFocused || hasError) ? 1.5 : 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: hasError ? AppColors.error : isFocused ? AppColors.primary : AppColors.systemGray),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscure,
                  textInputAction: textInputAction,
                  onSubmitted: onSubmitted,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.lightText,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: TextStyle(color: AppColors.systemGray2, fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    isDense: true,
                    filled: false,
                  ),
                ),
              ),
              if (suffix != null) suffix,
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 32),
            child: Text(error, style: const TextStyle(fontSize: 12, color: AppColors.error)),
          ),
      ],
    );
  }
}
