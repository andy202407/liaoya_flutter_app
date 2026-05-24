import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/api/api_client.dart';
import '../theme/app_colors.dart';
import 'avatar_widget.dart';

/// 群成员选择器底部弹窗 — 用于 @mention 选人
/// 显示群成员列表，支持搜索过滤，管理员可选"所有人"
///
/// Requirements: Component 2 (MemberPickerSheet)
class MemberPickerSheet extends StatefulWidget {
  /// 群组 ID
  final int groupId;

  /// 当前用户 ID（从列表中过滤掉）
  final int currentUserId;

  /// 是否为管理员或群主（可 @所有人）
  final bool isAdmin;

  /// 选择成员后的回调 (userId: int 或 "all", nickname: String)
  final void Function(dynamic userId, String nickname) onSelect;

  const MemberPickerSheet({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.isAdmin,
    required this.onSelect,
  });

  @override
  State<MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<MemberPickerSheet> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.dio.get(
        '/groups/${widget.groupId}/members',
      );

      final data = response.data;
      if (data['success'] == true && data['data'] is List) {
        final List<dynamic> rawMembers = data['data'];
        _members = rawMembers
            .cast<Map<String, dynamic>>()
            .where((m) {
              final userId = m['user_id'] ?? m['user']?['id'];
              return userId != widget.currentUserId;
            })
            .toList();

        // 排序：owner > admin > member
        _members.sort((a, b) {
          const roleOrder = {'owner': 0, 'admin': 1, 'member': 2};
          final roleA = roleOrder[a['role']] ?? 2;
          final roleB = roleOrder[b['role']] ?? 2;
          return roleA.compareTo(roleB);
        });

        _filteredMembers = List.from(_members);
      } else {
        _error = '获取成员列表失败';
      }
    } catch (e) {
      _error = '网络错误，请重试';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_members);
      } else {
        _filteredMembers = _members.where((m) {
          final nickname = _getNickname(m).toLowerCase();
          return nickname.contains(query);
        }).toList();
      }
    });
  }

  String _getNickname(Map<String, dynamic> member) {
    return member['user']?['nickname'] as String? ??
        member['nickname'] as String? ??
        '';
  }

  String? _getAvatar(Map<String, dynamic> member) {
    return member['user']?['avatar'] as String? ??
        member['avatar'] as String?;
  }

  int _getUserId(Map<String, dynamic> member) {
    return member['user_id'] as int? ??
        member['user']?['id'] as int? ??
        0;
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'owner':
        return '群主';
      case 'admin':
        return '管理员';
      default:
        return '';
    }
  }

  void _onMemberTap(dynamic userId, String nickname) {
    widget.onSelect(userId, nickname);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.6,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部拖拽手柄
          _buildHandle(isDark),
          // 标题
          _buildTitle(isDark),
          // 搜索框
          _buildSearchField(isDark),
          // 成员列表
          Expanded(child: _buildContent(isDark)),
        ],
      ),
    );
  }

  Widget _buildHandle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : Colors.black12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        '选择成员',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: _searchController,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          hintText: '搜索成员',
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
            fontSize: 15,
          ),
          prefixIcon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (_error != null) {
      return _buildErrorState(isDark);
    }

    if (_filteredMembers.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptyState(isDark, '没有匹配的成员');
    }

    if (_members.isEmpty) {
      return _buildEmptyState(isDark, '暂无群成员');
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: _filteredMembers.length + (widget.isAdmin ? 1 : 0),
      itemBuilder: (context, index) {
        // "所有人" 选项（仅管理员/群主可见）
        if (widget.isAdmin && index == 0) {
          return _buildAllMembersTile(isDark);
        }

        final memberIndex = widget.isAdmin ? index - 1 : index;
        final member = _filteredMembers[memberIndex];
        return _buildMemberTile(member, isDark);
      },
    );
  }

  Widget _buildAllMembersTile(bool isDark) {
    return InkWell(
      onTap: () => _onMemberTap('all', '所有人'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 所有人图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '所有人',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> member, bool isDark) {
    final nickname = _getNickname(member);
    final avatar = _getAvatar(member);
    final userId = _getUserId(member);
    final role = member['role'] as String?;
    final roleLabel = _getRoleLabel(role);

    return InkWell(
      onTap: () => _onMemberTap(userId, nickname),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AvatarWidget(
              url: avatar,
              name: nickname,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                nickname,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (roleLabel.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: role == 'owner'
                      ? AppColors.warning.withAlpha(25)
                      : AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: role == 'owner'
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 40,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _fetchMembers,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_2,
            size: 40,
            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
