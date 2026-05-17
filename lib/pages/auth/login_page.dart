import 'package:flutter/material.dart';
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
  bool _obscurePassword = true;
  bool _agreed = true;
  bool _rememberMe = true;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideAnim = Tween(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
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
      _showMsg('请输入用户名和密码');
      return;
    }
    if (!_agreed) {
      _showMsg('请先同意用户协议');
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
      _showMsg(auth.error!);
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 顶部渐变背景
          Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Stack(
              children: [
                Positioned(top: -30, right: -20, child: _decorCircle(120, 0.08)),
                Positioned(top: 60, left: -30, child: _decorCircle(80, 0.06)),
                Positioned(bottom: -20, right: 40, child: _decorCircle(60, 0.05)),
              ],
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // App 图标
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/images/logo.png', width: 88, height: 88, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('洽聊', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text('安全高效的即时通讯', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85), letterSpacing: 1)),
                      const SizedBox(height: 36),
                      // 登录卡片
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06), blurRadius: 20, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('欢迎回来', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Text('登录您的账户', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                            const SizedBox(height: 28),
                            // 用户名
                            _buildInputField(
                              controller: _usernameController,
                              hint: '请输入用户名',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 16),
                            // 密码
                            _buildInputField(
                              controller: _passwordController,
                              hint: '请输入密码',
                              icon: Icons.lock_outline_rounded,
                              isDark: isDark,
                              obscure: _obscurePassword,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: Icon(
                                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 20,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // 记住密码 + 协议
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          gradient: _rememberMe ? LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]) : null,
                                          color: _rememberMe ? null : Colors.transparent,
                                          border: _rememberMe ? null : Border.all(color: Colors.grey.shade400, width: 1.5),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: _rememberMe ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('记住密码', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            // 登录按钮
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                      : const Text('登 录', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 协议
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() => _agreed = !_agreed),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('已阅读并同意《用户协议》和《隐私政策》', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pushNamed('/register'),
                                child: Text('还没有账户？立即注册', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                              ),
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
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8EAF0), width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.6)),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.only(right: 12), child: suffix) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onSubmitted: (_) => _handleLogin(),
      ),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: opacity)),
    );
  }
}
