import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/conversation_provider.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import 'official_account_detail_page.dart';

class OfficialAccountListPage extends StatefulWidget {
  const OfficialAccountListPage({super.key});

  @override
  State<OfficialAccountListPage> createState() => _OfficialAccountListPageState();
}

class _OfficialAccountListPageState extends State<OfficialAccountListPage> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final res = await _dio.get('/user/official-accounts');
      if (res.data['success'] == true) {
        final List<dynamic> data = res.data['data'] ?? [];
        setState(() {
          _accounts = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[OfficialAccountList] error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleFollow(Map<String, dynamic> account, int index) async {
    final id = account['id'];
    final followed = account['followed'] == true;
    final newFollow = !followed;

    try {
      await _dio.post('/user/official-accounts/$id/follow', data: {'follow': newFollow});
      setState(() {
        _accounts[index] = {
          ..._accounts[index],
          'followed': newFollow,
          'followers': ((_accounts[index]['followers'] as int?) ?? 0) + (newFollow ? 1 : -1),
        };
      });
      // 刷新会话列表（关注/取关后会话会出现/消失）
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) context.read<ConversationProvider>().loadConversations();
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('公众号')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(child: Text('暂无公众号', style: AppTextStyles.body.copyWith(color: AppColors.lightTextTertiary)))
              : RefreshIndicator(
                  onRefresh: _loadAccounts,
                  child: ListView.builder(
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final name = account['name'] as String? ?? '公众号';
                      final avatar = account['avatar'] as String?;
                      final desc = account['description'] as String? ?? '';
                      final followed = account['followed'] == true;
                      final followers = account['followers'] as int? ?? 0;

                      return ListTile(
                        leading: AvatarWidget(url: avatar, name: name, size: 44),
                        title: Text(name, style: AppTextStyles.convName.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
                        subtitle: Text(desc.isNotEmpty ? desc : '$followers 人关注', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                        trailing: SizedBox(
                          width: 70,
                          height: 30,
                          child: OutlinedButton(
                            onPressed: () => _toggleFollow(account, index),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: followed ? Colors.transparent : AppColors.primary,
                              foregroundColor: followed ? AppColors.primary : Colors.white,
                              side: BorderSide(color: AppColors.primary, width: followed ? 1 : 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                            child: Text(followed ? '已关注' : '关注', style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => OfficialAccountDetailPage(account: account),
                          ));
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
