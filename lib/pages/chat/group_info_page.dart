import 'package:flutter/material.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class GroupInfoPage extends StatefulWidget {
  final int groupId;
  final String groupName;
  final String? groupAvatar;

  const GroupInfoPage({super.key, required this.groupId, required this.groupName, this.groupAvatar});

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final res = await _dio.get('/groups/${widget.groupId}/members');
      if (res.data['success'] == true) {
        final List<dynamic> data = res.data['data'] ?? [];
        setState(() {
          _members = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('群信息'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') _confirmClearMessages(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('清空消息')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 群信息卡片
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withAlpha(10) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      AvatarWidget(url: widget.groupAvatar, name: widget.groupName, size: 56, isGroup: true),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.groupName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 4),
                            Text('${_members.length} 位成员', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 成员列表
                Text('群成员 (${_members.length})', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 12),
                ..._members.map((member) => _buildMemberTile(member, isDark)),
              ],
            ),
    );
  }

  void _confirmClearMessages(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空消息'),
        content: const Text('确定要清空所有群消息吗？\n清空后，您将无法看到之前的消息，但仍可收到新消息。此操作仅对您生效。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await _dio.delete('/groups/${widget.groupId}/messages');
                if (res.data['success'] == true && mounted) {
                  Navigator.pop(context, 'cleared'); // 返回 chat_page 并通知清空
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('清空失败')));
                }
              }
            },
            child: const Text('确定清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, bool isDark) {
    final user = member['user'] as Map<String, dynamic>? ?? {};
    final nickname = (user['nickname'] ?? user['username'] ?? '用户').toString();
    final avatar = user['avatar']?.toString();
    final role = (member['role'] ?? '').toString();

    String? roleLabel;
    Color? roleColor;
    if (role == 'owner') {
      roleLabel = '群主';
      roleColor = const Color(0xFFFFB800);
    } else if (role == 'admin') {
      roleLabel = '管理员';
      roleColor = AppColors.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AvatarWidget(url: avatar, name: nickname, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(nickname, style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
          ),
          if (roleLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor!.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(roleLabel, style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }
}
