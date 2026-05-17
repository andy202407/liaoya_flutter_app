import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/theme_provider.dart';
import '../../widgets/avatar_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _soundEnabled = true;
  bool _popupEnabled = true;
  Map<String, dynamic>? _localUser;

  @override
  void initState() {
    super.initState();
    _loadNotifSettings();
    _loadLocalUser();
  }

  Future<void> _loadLocalUser() async {
    final storage = await StorageService.getInstance();
    final user = storage.getUser();
    if (user != null && mounted) {
      setState(() => _localUser = user);
    }
  }

  Future<void> _loadNotifSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('chat_sound_enabled') ?? true;
      _popupEnabled = prefs.getBool('chat_popup_enabled') ?? true;
    });
  }

  Future<void> _saveNotifSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_sound_enabled', _soundEnabled);
    await prefs.setBool('chat_popup_enabled', _popupEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.user ?? _localUser;

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          // 用户信息卡片
          _buildUserCard(context, auth, user, isDark),

          const SizedBox(height: AppSpacing.lg),

          // 账号信息
          _buildSection(context, '账号信息', [
            _buildItem(context, Icons.wallet_rounded, '我的钱包', isDark, onTap: () => _showWallet(context)),
            _buildItem(context, Icons.lock_outline_rounded, '修改密码', isDark, onTap: () => _showChangePassword(context)),
          ]),

          const SizedBox(height: AppSpacing.sm),

          // 消息与通知（暂未联动，先隐藏）
          // _buildSection(context, '消息与通知', [
          //   _buildSwitchItem(context, Icons.volume_up_rounded, '消息提示音', '收到新消息时播放提示音', isDark,
          //     value: _soundEnabled,
          //     onChanged: (v) { setState(() => _soundEnabled = v); _saveNotifSettings(); },
          //   ),
          //   _buildSwitchItem(context, Icons.notifications_active_rounded, '消息弹窗', '收到新消息时顶部弹窗提醒', isDark,
          //     value: _popupEnabled,
          //     onChanged: (v) { setState(() => _popupEnabled = v); _saveNotifSettings(); },
          //   ),
          // ]),

          // const SizedBox(height: AppSpacing.sm),

          // 应用偏好
          _buildSection(context, '应用偏好', [
            _buildSwitchItem(context, Icons.dark_mode_rounded, '深色模式', null, isDark,
              value: theme.isDark,
              onChanged: (_) => theme.toggleTheme(),
            ),
            _buildItem(context, Icons.cleaning_services_rounded, '清除缓存', isDark, onTap: () => _clearCache(context)),
            _buildItem(context, Icons.system_update_rounded, '检查更新', isDark, onTap: () => _checkUpdate(context)),
            _buildVersionItem(context, isDark),
          ]),

          const SizedBox(height: AppSpacing.xxxl),

          // 退出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _logout(context, auth),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.error.withAlpha(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                ),
                child: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthProvider auth, Map<String, dynamic>? user, bool isDark) {
    final nickname = user?['nickname'] ?? '用户';
    final username = user?['username'] ?? '';
    final avatar = user?['avatar'] as String?;
    final userId = auth.userId ?? user?['id'];

    return GestureDetector(
      onTap: () => _showEditNickname(context, auth, nickname),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // 头像 + 相机图标
            GestureDetector(
              onTap: () => _showAvatarPicker(context, auth),
              child: Stack(
                children: [
                  AvatarWidget(url: avatar, name: nickname, size: 56),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nickname, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(width: 6),
                      Icon(Icons.edit, size: 14, color: isDark ? Colors.white38 : Colors.black26),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('@$username', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: '$userId'));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID已复制'), duration: Duration(seconds: 1)));
                    },
                    child: Row(
                      children: [
                        Text('ID: $userId', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 12, color: isDark ? Colors.white38 : Colors.black26),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg + 4, 8, 0, 6),
          child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white38 : Colors.black38)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String title, bool isDark, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: AppTextStyles.body),
      trailing: Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? Colors.white24 : Colors.black26),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(BuildContext context, IconData icon, String title, String? subtitle, bool isDark, {required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: AppTextStyles.body),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)) : null,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
    );
  }

  Widget _buildVersionItem(BuildContext context, bool isDark) {
    return ListTile(
      leading: Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
      title: Text('当前版本', style: AppTextStyles.body),
      trailing: Text('1.0.0', style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black45)),
    );
  }

  void _showAvatarPicker(BuildContext context, AuthProvider auth) async {
    // 获取默认头像列表
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

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('选择头像', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: GridView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
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

    // 设置选中的头像
    try {
      final res = await ApiClient.instance.dio.post('/user/avatar/default', data: {'avatar_url': selected});
      if (res.data['success'] == true) {
        await auth.refreshProfile();
        _loadLocalUser();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
      }
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
    }
  }

  void _showEditNickname(BuildContext context, AuthProvider auth, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新昵称'),
          maxLength: 50,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.dio.put('/user/nickname', data: {'nickname': newNickname});
                await auth.refreshProfile();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('昵称已更新')));
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('更新失败')));
              }
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '当前密码')),
            const SizedBox(height: 8),
            TextField(controller: newPwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: '新密码')),
            const SizedBox(height: 8),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: '确认新密码')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('修改失败，请检查当前密码')));
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
    // 保留 token 和 user 数据，只清除其他缓存
    final token = prefs.getString('token');
    final user = prefs.getString('user');
    await prefs.clear();
    if (token != null) await prefs.setString('token', token);
    if (user != null) await prefs.setString('user', user);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('缓存已清除')));
  }

  Future<void> _checkUpdate(BuildContext context) async {
    try {
      final dio = ApiClient.instance.dio;
      final res = await dio.get('/android/config');
      if (res.data?['success'] == true && res.data?['data'] != null) {
        final data = res.data['data'];
        final apkUrl = data['apk_url']?.toString() ?? '';
        final latestVersion = data['version']?.toString() ?? '';
        final updateMessage = data['update_message']?.toString() ?? '';
        final forceUpdate = data['force_update'] == true;
        if (apkUrl.isEmpty || latestVersion.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可用更新')));
          return;
        }
        const currentVersion = '1.0.0';
        if (_compareVersions(latestVersion, currentVersion) > 0) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: !forceUpdate,
            builder: (ctx) => AlertDialog(
              title: const Text('发现新版本'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('最新版本: $latestVersion'),
                  Text('当前版本: $currentVersion'),
                  if (updateMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(updateMessage),
                  ],
                ],
              ),
              actions: [
                if (!forceUpdate)
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('稍后')),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _downloadAndInstall(apkUrl);
                  },
                  child: const Text('立即更新'),
                ),
              ],
            ),
          );
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已是最新版本')));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无可用更新')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('检查更新失败: $e')));
    }
  }

  /// Compare two version strings (e.g. "1.0.1" vs "1.0.0")
  /// Returns positive if v1 > v2, negative if v1 < v2, 0 if equal
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
    // 使用 url_launcher 打开下载链接（系统浏览器下载并安装）
    final uri = Uri.parse(apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showWallet(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _WalletPage()));
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
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

class _WalletPageState extends State<_WalletPage> with SingleTickerProviderStateMixin {
  final _dio = ApiClient.instance.dio;
  late TabController _tabController;
  double _balance = 0;
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        if (rawData is List) {
          items = rawData;
        } else if (rawData is Map) {
          items = rawData['records'] ?? rawData['logs'] ?? rawData['items'] ?? [];
        }
        _logs = items.whereType<Map<String, dynamic>>().toList();
      }
      final wdRes = await _dio.get('/user/withdrawal/list');
      if (wdRes.data['success'] == true) {
        final rawData = wdRes.data['data'];
        List<dynamic> items = [];
        if (rawData is List) {
          items = rawData;
        } else if (rawData is Map) {
          items = rawData['records'] ?? rawData['list'] ?? rawData['items'] ?? [];
        }
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
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  // 余额卡片
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C5CFC), Color(0xFFA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                        OutlinedButton(
                          onPressed: () => _showWithdrawDialog(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          ),
                          child: const Text('提现'),
                        ),
                      ],
                    ),
                  ),
                  // Tab 切换
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                    indicatorColor: AppColors.primary,
                    tabs: const [
                      Tab(text: '余额流水'),
                      Tab(text: '提现记录'),
                    ],
                  ),
                  // Tab 内容
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLogsList(isDark),
                        _buildWithdrawalsList(isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLogsList(bool isDark) {
    if (_logs.isEmpty) {
      return Center(child: Text('暂无记录', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
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
                    Text(desc, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(_formatTime(time), style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
              Text(
                '${isIncome ? '+' : ''}${amount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isIncome ? Colors.green : Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWithdrawalsList(bool isDark) {
    if (_withdrawals.isEmpty) {
      return Center(child: Text('暂无提现记录', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawals.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
      itemBuilder: (_, index) {
        final wd = _withdrawals[index];
        final amount = (wd['amount'] as num?)?.toDouble() ?? 0;
        final status = (wd['status'] ?? 'pending').toString();
        final time = (wd['created_at'] ?? '').toString();

        String statusText;
        Color statusColor;
        final statusInt = int.tryParse(status) ?? -1;
        switch (statusInt) {
          case 1: statusText = '已批准'; statusColor = Colors.green; break;
          case 2: statusText = '已拒绝'; statusColor = Colors.red; break;
          case 0: statusText = '待审核'; statusColor = Colors.orange; break;
          default:
            switch (status) {
              case 'approved': statusText = '已批准'; statusColor = Colors.green; break;
              case 'rejected': statusText = '已拒绝'; statusColor = Colors.red; break;
              default: statusText = '待审核'; statusColor = Colors.orange; break;
            }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('提现 ¥${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Text(_formatTime(time), style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('申请提现'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('可提现余额: ¥${_balance.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '提现金额', prefixText: '¥')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
                return;
              }
              if (amount > _balance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('余额不足')));
                return;
              }
              Navigator.pop(ctx);
              try {
                final res = await _dio.post('/user/withdrawal', data: {'amount': amount});
                if (res.data['success'] == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提现申请已提交')));
                  _loadData();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.data['message'] ?? '提现失败')));
                }
              } catch (_) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('提现失败')));
              }
            },
            child: const Text('确认提现'),
          ),
        ],
      ),
    );
  }

  String _getTypeLabel(String type) {
    const map = {
      'recharge': '充值',
      'send_red_packet': '发红包',
      'grab_red_packet': '收红包',
      'refund_red_packet': '红包退回',
      'withdrawal': '提现',
      'withdrawal_refund': '提现退回',
    };
    return map[type] ?? type;
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final time = DateTime.parse(timeStr);
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
