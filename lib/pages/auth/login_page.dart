import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;
  bool _agreed = true;
  bool _rememberMe = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnim = Tween(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: const Interval(0.1, 1.0, curve: Curves.easeOut)));
    _animController.forward();
    _loadSavedCredentials();
    _usernameFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  Future<void> _loadSavedCredentials() async {
    final storage = await StorageService.getInstance();
    final saved = storage.getSavedCredentials();
    if (saved != null) {
      _usernameController.text = saved['username'] ?? '';
      _passwordController.text = saved['password'] ?? '';
      setState(() => _rememberMe = true);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _showMsg('请输入用户名和密码');
      return;
    }
    if (!_agreed) {
      _showMsg('请先同意用户协议');
      return;
    }

    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    final success = await auth.login(username, password);
    if (success && mounted) {
      final storage = await StorageService.getInstance();
      if (_rememberMe) {
        await storage.saveCredentials(username, password);
      } else {
        await storage.clearCredentials();
      }
      context.read<ConversationProvider>().reset();
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
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
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(msg),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 56),
                  // App 图标
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset('assets/images/logo.png', width: 76, height: 76, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '洽聊',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '安全高效的即时通讯',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.systemGray,
                    ),
                  ),
                  const SizedBox(height: 44),
                  // 用户名
                  _buildTextField(
                    controller: _usernameController,
                    focusNode: _usernameFocus,
                    placeholder: '请输入用户名',
                    icon: CupertinoIcons.person,
                    isDark: isDark,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  // 密码
                  _buildTextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    placeholder: '请输入密码',
                    icon: CupertinoIcons.lock,
                    isDark: isDark,
                    obscure: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _handleLogin(),
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _obscurePassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
                          size: 20,
                          color: AppColors.systemGray,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 记住密码
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rememberMe = !_rememberMe);
                    },
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _rememberMe ? AppColors.primary : Colors.transparent,
                            border: _rememberMe ? null : Border.all(color: AppColors.systemGray3, width: 1.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: _rememberMe
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '记住密码',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: auth.isLoading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('登录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 协议
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _agreed = !_agreed);
                        },
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: _agreed ? AppColors.primary : Colors.transparent,
                            border: _agreed ? null : Border.all(color: AppColors.systemGray3, width: 1),
                            shape: BoxShape.circle,
                          ),
                          child: _agreed
                              ? const Icon(Icons.check, size: 10, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('已阅读并同意', style: TextStyle(fontSize: 12, color: AppColors.systemGray)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('《用户协议》', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                      Text('和', style: TextStyle(fontSize: 12, color: AppColors.systemGray)),
                      GestureDetector(
                        onTap: () {},
                        child: Text('《隐私政策》', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/register'),
                    child: Text(
                      '还没有账户？立即注册',
                      style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
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
    bool obscure = false,
    Widget? suffix,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isFocused
                ? AppColors.primary
                : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
            width: isFocused ? 1.5 : 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isFocused ? AppColors.primary : AppColors.systemGray),
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
    );
  }
}
