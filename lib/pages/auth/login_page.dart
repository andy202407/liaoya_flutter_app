import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreed = true;
  bool _rememberMe = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _loadSavedCredentials();
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
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入用户名和密码')));
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先同意用户协议')));
      return;
    }

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Logo
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('聊鸭', style: AppTextStyles.h1.copyWith(color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('欢迎回来', style: AppTextStyles.body.copyWith(color: Colors.white60)),
                    const SizedBox(height: 40),

                    // 表单卡片
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 12)),
                        ],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(hintText: '用户名', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 14),

                          // 记住密码
                          Row(
                            children: [
                              SizedBox(
                                width: 20, height: 20,
                                child: Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? false)),
                              ),
                              const SizedBox(width: 8),
                              Text('记住密码', style: AppTextStyles.caption.copyWith(color: AppColors.lightTextSecondary)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 登录按钮
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              child: auth.isLoading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('登录'),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // 协议
                          Row(
                            children: [
                              SizedBox(
                                width: 16, height: 16,
                                child: Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('已阅读并同意《用户协议》和《隐私政策》', style: AppTextStyles.captionSm.copyWith(color: AppColors.lightTextTertiary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/register'),
                            child: const Text('还没有账户？立即注册'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
