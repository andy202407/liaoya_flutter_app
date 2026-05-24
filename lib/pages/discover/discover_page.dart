import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../providers/check_in_provider.dart';
import 'check_in_page.dart';
import 'official_account_list_page.dart';
import 'live_stream_list_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    try {
      final response = await ApiClient.instance.dio.get('/user/discovery-menu');
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _menuItems = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[DiscoverPage] load menu error: $e');
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : CustomScrollView(
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
                    '发现',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  centerTitle: true,
                ),
                CupertinoSliverRefreshControl(
                  onRefresh: _loadMenu,
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: List.generate(_menuItems.length, (index) {
                          final item = _menuItems[index];
                          final name = item['name'] as String? ?? '';
                          final colorHex = item['color'] as String? ?? '#007AFF';
                          final color = _parseColor(colorHex);
                          final key = item['key'] as String? ?? '';
                          final isLast = index == _menuItems.length - 1;

                          return Column(
                            children: [
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => _onItemTap(key),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(_getIcon(key), color: Colors.white, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: isDark ? AppColors.darkText : AppColors.lightText,
                                          ),
                                        ),
                                      ),
                                      // 签到红点
                                      if (key == 'checkin' && context.watch<CheckInProvider>().showBadge)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.error,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.systemGray3),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isLast)
                                Padding(
                                  padding: const EdgeInsets.only(left: 60),
                                  child: Divider(
                                    height: 0.33,
                                    color: isDark ? AppColors.darkDivider : AppColors.lightDivider,
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  IconData _getIcon(String key) {
    switch (key) {
      case 'checkin': return CupertinoIcons.checkmark_seal;
      case 'official': return CupertinoIcons.doc_text;
      case 'video': return CupertinoIcons.play_circle;
      case 'sports': return CupertinoIcons.tv;
      case 'moments': return CupertinoIcons.camera;
      case 'shake': return CupertinoIcons.waveform;
      case 'bottle': return CupertinoIcons.drop;
      case 'games': return CupertinoIcons.game_controller;
      case 'miniprogram': return CupertinoIcons.square_grid_2x2;
      case 'shopping': return CupertinoIcons.bag;
      case 'nearby': return CupertinoIcons.location;
      default: return CupertinoIcons.compass;
    }
  }

  void _onItemTap(String key) {
    HapticFeedback.selectionClick();
    switch (key) {
      case 'checkin':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const CheckInPage()));
        break;
      case 'official':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const OfficialAccountListPage()));
        break;
      case 'sports':
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const LiveStreamListPage()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$key 功能开发中'), duration: const Duration(seconds: 1)),
        );
    }
  }
}
