import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/avatar_widget.dart';
import 'scan_join_group_page.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await context.read<FriendProvider>().searchUsers(keyword);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'æœç´¢å¤±è´¥');
    }
    setState(() => _searching = false);
  }

  Future<void> _sendRequestByUsername() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;

    setState(() => _searching = true);
    try {
      final success = await context.read<FriendProvider>().sendFriendRequestByUsername(username, 'æˆ‘æƒ³æ·»åŠ æ‚¨ä¸ºå¥½å‹');
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('å¥½å‹ç”³è¯·å·²å‘é€')));
        // å»¶è¿Ÿåˆ·æ–°ä¼šè¯åˆ—è¡¨ï¼ˆè‡ªåŠ¨é€šè¿‡æ—¶æ–°ä¼šè¯éœ€è¦å‡ºçŽ°ï¼‰
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.read<ConversationProvider>().loadConversations();
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().contains('response') ? 'å‘é€å¤±è´¥' : 'ç”¨æˆ·ä¸å­˜åœ¨';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _sendRequest(int userId) async {
    final success = await context.read<FriendProvider>().sendFriendRequest(userId, 'æˆ‘æƒ³æ·»åŠ æ‚¨ä¸ºå¥½å‹');
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('æ“ä½œæˆåŠŸ')));
      // å»¶è¿Ÿåˆ·æ–°ä¼šè¯åˆ—è¡¨ï¼ˆè‡ªåŠ¨é€šè¿‡æ—¶æ–°ä¼šè¯éœ€è¦å‡ºçŽ°ï¼‰
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) context.read<ConversationProvider>().loadConversations();
      });
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('å‘é€å¤±è´¥')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('æ·»åŠ å¥½å‹')),
      body: Column(
        children: [
          // æœç´¢æ¡†
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'è¾“å…¥ç”¨æˆ·åæœç´¢',
                      prefixIcon: const Icon(Icons.search_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
                  ),
                  child: const Text('æœç´¢'),
                ),
              ],
            ),
          ),

          // ç›´æŽ¥é€šè¿‡ç”¨æˆ·åæ·»åŠ 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _searching ? null : _sendRequestByUsername,
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('ç›´æŽ¥é€šè¿‡ç”¨æˆ·åæ·»åŠ '),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
                ),
              ),
            ),
          ),


          // Scan QR to join group
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScanJoinGroupPage()),
                  );
                  if (result != null && mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('\u626b\u4e00\u626b\u52a0\u5165\u7fa4\u804a'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusXl)),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // æœç´¢ç»“æžœ
          if (_searching)
            const Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())
          else if (_error != null)
            Padding(padding: const EdgeInsets.all(32), child: Text(_error!, style: TextStyle(color: AppColors.error)))
          else if (_results.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final user = _results[index];
                  final name = user['nickname'] ?? user['username'] ?? 'ç”¨æˆ·';
                  final username = user['username'] ?? '';
                  final avatar = user['avatar'] as String?;
                  final userId = user['id'] as int? ?? 0;

                  return ListTile(
                    leading: AvatarWidget(url: avatar, name: name, size: 44),
                    title: Text(name, style: AppTextStyles.convName.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
                    subtitle: Text('@$username', style: AppTextStyles.caption.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    trailing: ElevatedButton(
                      onPressed: () => _sendRequest(userId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('æ·»åŠ ', style: TextStyle(fontSize: 13)),
                    ),
                  );
                },
              ),
            )
          else if (_searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  const SizedBox(height: 12),
                  Text('æœªæ‰¾åˆ°ç”¨æˆ·', style: AppTextStyles.body.copyWith(color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
