import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:open_filex/open_filex.dart';

import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/api/api_client.dart';
import '../../config/api_config.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _hasUpdate = false;
  Map<String, dynamic>? _localUser;

  @override
  void initState() {
    super.initState();
    _loadLocalUser();
    _checkHasUpdate();
  }

  Future<void> _checkHasUpdate() async {
    try {
      final dio = ApiClient.instance.dio;
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      final configPath = isIOS ? '/app/version/ios' : '/app/version/android';
      final res = await dio.get(configPath);
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        final latestVersion = data['version']?.toString() ?? '';
        final downloadUrl = isIOS
            ? (data['download_url']?.toString() ?? '')
            : (data['apk_url']?.toString() ?? '');
        if (latestVersion.isEmpty || downloadUrl.isEmpty) return;
        final packageInfo = await PackageInfo.fromPlatform();
        if (_compareVersions(latestVersion, packageInfo.version) > 0) {
          if (mounted) setState(() => _hasUpdate = true);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLocalUser() async {
    final storage = await StorageService.getInstance();
    final user = storage.getUser();
    if (user != null && mounted) {
      setState(() => _localUser = user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.user ?? _localUser;

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 52,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Container(
                  color: isDark
                      ? AppColors.darkBg.withValues(alpha: 0.60)
                      : Colors.white.withValues(alpha: 0.65),
                ),
              ],
            ),
            title: Text(
              '我的',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            centerTitle: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // 用户信息卡片 - 渐变背景
                  _buildUserCard(context, auth, user, isDark),
                  const SizedBox(height: 28),

                  // 账号信息
                  _buildSectionHeader('账号信息', isDark),
                  const SizedBox(height: 8),
                  _buildGroupedList(context, isDark, [
                    _buildIOSItem(context, CupertinoIcons.creditcard, '我的钱包', isDark, onTap: () => _showWallet(context)),
                    _buildIOSItem(context, CupertinoIcons.lock, '修改密码', isDark, onTap: () => _showChangePassword(context), isLast: true),
                  ]),

                  const SizedBox(height: 28),

                  // 应用偏好
                  _buildSectionHeader('应用偏好', isDark),
                  const SizedBox(height: 8),
                  _buildGroupedList(context, isDark, [
                    _buildIOSSwitchItem(context, CupertinoIcons.moon, '深色模式', isDark,
                      value: theme.isDark,
                      onChanged: (_) => theme.toggleTheme(),
                    ),
                    _buildIOSItem(context, CupertinoIcons.trash, '清除缓存', isDark, onTap: () => _clearCache(context)),
                    _buildIOSItem(context, CupertinoIcons.arrow_down_circle, '检查更新', isDark,
                      trailing: _hasUpdate ? _buildNewBadge() : null,
                      onTap: () => _checkUpdate(context),
                    ),
                    _buildVersionItem(context, isDark),
                  ]),

                  const SizedBox(height: 36),

                  // 退出按钮
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.error.withAlpha(40),
                        width: 1,
                      ),
                    ),
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onPressed: () => _logout(context, auth),
                      child: const Text(
                        '退出登录',
                        style: TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextSecondary : AppColors.systemGray,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, bool isDark, List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  Widget _buildNewBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A24)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthProvider auth, Map<String, dynamic>? user, bool isDark) {
    final nickname = user?['nickname'] ?? '用户';
    final username = user?['username'] ?? '';
    final avatar = user?['avatar'] as String?;
    final userId = auth.userId ?? user?['id'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF2A2A3E), Color(0xFF1E1E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFF8F9FF), Color(0xFFEEF0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(60) : AppColors.primary.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(10) : AppColors.primary.withAlpha(20),
          width: 1,
        ),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () => _showEditNickname(context, auth, nickname),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _showAvatarPicker(context, auth),
              child: Stack(
                children: [
                  AvatarWidget(url: avatar, name: nickname, size: 64),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF8F9FF), width: 2.5),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 6, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.camera, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppColors.lightText),
                  ),
                  const SizedBox(height: 4),
                  Text('@$username', style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.systemGray)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '$userId'));
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(10) : AppColors.primary.withAlpha(10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('ID: $userId', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray2)),
                          const SizedBox(width: 4),
                          Icon(CupertinoIcons.doc_on_doc, size: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray3),
          ],
        ),
      ),
    );
  }

  Widget _buildIOSItem(BuildContext context, IconData icon, String title, bool isDark, {VoidCallback? onTap, Widget? trailing, bool isLast = false}) {
    return Column(
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary.withAlpha(20) : AppColors.primary.withAlpha(12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkText : AppColors.lightText)),
                ),
                if (trailing != null) ...[trailing, const SizedBox(width: 8)],
                Icon(CupertinoIcons.chevron_right, size: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray3),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 66),
            child: Divider(height: 0.5, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
          ),
      ],
    );
  }

  Widget _buildIOSSwitchItem(BuildContext context, IconData icon, String title, bool isDark, {required bool value, required ValueChanged<bool> onChanged}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withAlpha(20) : AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(title, style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 66),
          child: Divider(height: 0.5, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
        ),
      ],
    );
  }

  Widget _buildVersionItem(BuildContext context, bool isDark) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '...';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withAlpha(20) : AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(CupertinoIcons.info, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('当前版本', style: TextStyle(fontSize: 16, color: isDark ? AppColors.darkText : AppColors.lightText)),
              ),
              Text(version, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextTertiary : AppColors.systemGray)),
            ],
          ),
        );
      },
    );
  }

  void _showAvatarPicker(BuildContext context, AuthProvider auth) async {
    List<String> avatars = [];
    try {
      final res = await ApiClient.instance.dio.get('/user/default-avatars');
      if (res.data['success'] == true) {
        final List<dynamic> data = res.data['data'] ?? [];
        avatars = data.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    if (avatars.isEmpty || !context.mounted) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可用头像')));
      return;
    }

    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                  const Text('选择头像', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 60),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10,
                ),
                itemCount: avatars.length,
                itemBuilder: (_, index) {
                  final url = avatars[index];
                  return GestureDetector(
                    onTap: () => Navigator.pop(ctx, url),
                    child: AvatarWidget(url: url, name: '${index + 1}', size: 54),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null || !context.mounted) return;
    try {
      final res = await ApiClient.instance.dio.post('/user/avatar/default', data: {'avatar_url': selected});
      if (res.data['success'] == true) {
        await auth.refreshProfile();
        _loadLocalUser();
      }
    } catch (_) {}
  }

  void _showEditNickname(BuildContext context, AuthProvider auth, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('修改昵称'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(controller: controller, autofocus: true, placeholder: '输入新昵称', maxLength: 50),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.dio.put('/user/nickname', data: {'nickname': newNickname});
                await auth.refreshProfile();
              } catch (_) {}
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final oldPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('修改密码'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(controller: oldPwdCtrl, obscureText: true, placeholder: '当前密码', padding: const EdgeInsets.all(12)),
              const SizedBox(height: 8),
              CupertinoTextField(controller: newPwdCtrl, obscureText: true, placeholder: '新密码', padding: const EdgeInsets.all(12)),
              const SizedBox(height: 8),
              CupertinoTextField(controller: confirmCtrl, obscureText: true, placeholder: '确认新密码', padding: const EdgeInsets.all(12)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              if (newPwdCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('两次密码不一致')));
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.dio.post('/user/change-password', data: {
                  'old_password': oldPwdCtrl.text,
                  'new_password': newPwdCtrl.text,
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已修改')));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改失败')));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final user = prefs.getString('user');
    await prefs.clear();
    if (token != null) await prefs.setString('token', token);
    if (user != null) await prefs.setString('user', user);
    // 清除图片磁盘缓存
    await DefaultCacheManager().emptyCache();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
  }

  Future<void> _checkUpdate(BuildContext context) async {
    try {
      final dio = ApiClient.instance.dio;
      final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
      final configPath = isIOS ? '/app/version/ios' : '/app/version/android';
      final res = await dio.get(configPath);
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        final downloadUrl = isIOS
            ? (data['download_url']?.toString() ?? '')
            : (data['apk_url']?.toString() ?? '');
        final latestVersion = data['version']?.toString() ?? '';
        final updateMessage = data['update_message']?.toString() ?? '';
        final forceUpdate = data['force_update'] == true;
        if (downloadUrl.isEmpty || latestVersion.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可用更新')));
          return;
        }
        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        if (_compareVersions(latestVersion, currentVersion) > 0) {
          if (!mounted) return;
          showCupertinoDialog(
            context: context,
            barrierDismissible: !forceUpdate,
            builder: (ctx) => CupertinoAlertDialog(
              title: const Text('发现新版本'),
              content: Column(
                children: [
                  const SizedBox(height: 8),
                  Text('最新版本: $latestVersion\n当前版本: $currentVersion'),
                  if (updateMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(updateMessage, style: const TextStyle(fontSize: 13)),
                  ],
                ],
              ),
              actions: [
                if (!forceUpdate)
                  CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadAndInstall(downloadUrl);
                  },
                  child: const Text('立即更新'),
                ),
              ],
            ),
          );
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已是最新版本')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检查更新失败: $e')));
    }
  }

  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < len; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  Future<void> _downloadAndInstall(String apkUrl) async {
    // iOS 或非 APK 链接：直接打开浏览器
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIOS || (!apkUrl.endsWith('.apk') && !apkUrl.contains('/apk'))) {
      String fullUrl = apkUrl;
      if (!apkUrl.startsWith('http')) {
        fullUrl = '${ApiConfig.baseUrl}$apkUrl';
      }
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Android APK：应用内下载并安装
    String fullUrl = apkUrl;
    if (!apkUrl.startsWith('http')) {
      fullUrl = '${ApiConfig.baseUrl}$apkUrl';
    }

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update.apk';

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ApkDownloadDialog(url: fullUrl, savePath: savePath),
      );
    } catch (e) {
      debugPrint('[Update] Download error: $e');
      final uri = Uri.parse(fullUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showWallet(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const _WalletPage()));
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('退出登录'),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('确定要退出当前账号吗？'),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await auth.logout();
    if (context.mounted) {
      context.read<ConversationProvider>().reset();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}

/// 钱包页面
class _WalletPage extends StatefulWidget {
  const _WalletPage();

  @override
  State<_WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<_WalletPage> {
  final _dio = ApiClient.instance.dio;
  double _balance = 0;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final balanceRes = await _dio.get('/user/balance');
      if (balanceRes.data['success'] == true) {
        _balance = (balanceRes.data['data']?['balance'] as num?)?.toDouble() ?? 0;
      }
      final logsRes = await _dio.get('/user/balance/logs', queryParameters: {'page': 1, 'page_size': 50});
      if (logsRes.data['success'] == true) {
        final rawData = logsRes.data['data'];
        List<dynamic> items = [];
        if (rawData is List) { items = rawData; }
        else if (rawData is Map) { items = rawData['records'] ?? rawData['logs'] ?? rawData['items'] ?? []; }
        _logs = items.whereType<Map<String, dynamic>>().toList();
      }
      final wdRes = await _dio.get('/user/withdrawal/list');
      if (wdRes.data['success'] == true) {
        final rawData = wdRes.data['data'];
        List<dynamic> items = [];
        if (rawData is List) { items = rawData; }
        else if (rawData is Map) { items = rawData['records'] ?? rawData['list'] ?? rawData['items'] ?? []; }
        _withdrawals = items.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('我的钱包')),
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
              children: [
                // 余额卡片
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('账户余额（元）', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text('¥${_balance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () => _showWithdrawDialog(context),
                        child: const Text('提现', style: TextStyle(color: Colors.white, fontSize: 14)),
                      ),
                    ],
                  ),
                ),
                // iOS 分段控制器
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _selectedTab,
                    onValueChanged: (v) => setState(() => _selectedTab = v ?? 0),
                    children: const {
                      0: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('余额流水')),
                      1: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('提现记录')),
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _selectedTab == 0 ? _buildLogsList(isDark) : _buildWithdrawalsList(isDark),
                ),
              ],
            ),
    );
  }

  Widget _buildLogsList(bool isDark) {
    if (_logs.isEmpty) {
      return Center(child: Text('暂无记录', style: TextStyle(color: AppColors.systemGray)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      itemBuilder: (_, index) {
        final log = _logs[index];
        final amount = (log['amount'] as num?)?.toDouble() ?? 0;
        final typeKey = (log['type'] ?? '').toString();
        final desc = _getTypeLabel(typeKey);
        final time = (log['created_at'] ?? '').toString();
        final isIncome = ['recharge', 'grab_red_packet', 'refund_red_packet', 'withdrawal_refund'].contains(typeKey);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc, style: TextStyle(fontSize: 15, color: isDark ? Colors.white : AppColors.lightText)),
                    const SizedBox(height: 2),
                    Text(_formatDateTime(time), style: TextStyle(fontSize: 12, color: AppColors.systemGray)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : '-'}¥${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isIncome ? AppColors.success : AppColors.error),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalsList(bool isDark) {
    if (_withdrawals.isEmpty) {
      return Center(child: Text('暂无记录', style: TextStyle(color: AppColors.systemGray)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawals.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.lightDivider),
      itemBuilder: (_, index) {
        final wd = _withdrawals[index];
        final amount = (wd['amount'] as num?)?.toDouble() ?? 0;
        final status = (wd['status'] ?? '').toString();
        final time = (wd['created_at'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('提现 ¥${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : AppColors.lightText)),
                    const SizedBox(height: 2),
                    Text(_formatDateTime(time), style: TextStyle(fontSize: 12, color: AppColors.systemGray)),
                  ],
                ),
              ),
              Text(_getStatusLabel(status), style: TextStyle(fontSize: 13, color: _getStatusColor(status))),
            ],
          ),
        );
      },
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'recharge': return '充值';
      case 'send_red_packet': return '发红包';
      case 'grab_red_packet': return '收红包';
      case 'refund_red_packet': return '红包退款';
      case 'withdrawal': return '提现';
      case 'withdrawal_refund': return '提现退款';
      default: return type;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return '处理中';
      case 'approved': return '已通过';
      case 'rejected': return '已拒绝';
      case 'completed': return '已完成';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return AppColors.warning;
      case 'approved': case 'completed': return AppColors.success;
      case 'rejected': return AppColors.error;
      default: return AppColors.systemGray;
    }
  }

  String _formatDateTime(String timeStr) {
    try {
      final dt = DateTime.parse(timeStr);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timeStr;
    }
  }

  void _showWithdrawDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final accountCtrl = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('提现'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              CupertinoTextField(controller: amountCtrl, placeholder: '提现金额', keyboardType: TextInputType.number, padding: const EdgeInsets.all(12)),
              const SizedBox(height: 8),
              CupertinoTextField(controller: accountCtrl, placeholder: '收款账号', padding: const EdgeInsets.all(12)),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0) return;
              Navigator.pop(ctx);
              try {
                await _dio.post('/user/withdrawal', data: {'amount': amount, 'account': accountCtrl.text});
                _loadData();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提现申请已提交')));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提现失败')));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// APK 下载进度对话框
class _ApkDownloadDialog extends StatefulWidget {
  final String url;
  final String savePath;

  const _ApkDownloadDialog({required this.url, required this.savePath});

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  double _progress = 0;
  bool _downloading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      final d = dio_pkg.Dio();
      await d.download(
        widget.url,
        widget.savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);
      final result = await OpenFilex.open(widget.savePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() => _error = '安装失败: ${result.message}');
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '下载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_error != null ? '更新失败' : '正在下载更新'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))
          else ...[
            LinearProgressIndicator(value: _downloading ? _progress : 1.0),
            const SizedBox(height: 12),
            Text('${(_progress * 100).toStringAsFixed(0)}%'),
          ],
        ],
      ),
      actions: [
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
