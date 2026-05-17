import 'package:flutter/material.dart';
import '../../services/api/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'check_in_page.dart';
import 'official_account_list_page.dart';

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
      appBar: AppBar(title: const Text('发现')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMenu,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final name = item['name'] as String? ?? '';
                  final colorHex = item['color'] as String? ?? '#6366F1';
                  final color = _parseColor(colorHex);
                  final key = item['key'] as String? ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: index == 0
                          ? const BorderRadius.vertical(top: Radius.circular(12))
                          : index == _menuItems.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(12))
                              : BorderRadius.zero,
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getIcon(key), color: color, size: 20),
                      ),
                      title: Text(name, style: AppTextStyles.body.copyWith(color: isDark ? AppColors.darkText : AppColors.lightText)),
                      trailing: Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                      onTap: () => _onItemTap(key),
                    ),
                  );
                },
              ),
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
      case 'checkin': return Icons.check_circle_rounded;
      case 'official': return Icons.article_rounded;
      case 'video': return Icons.play_circle_rounded;
      case 'sports': return Icons.live_tv_rounded;
      case 'moments': return Icons.photo_camera_rounded;
      case 'shake': return Icons.vibration_rounded;
      case 'bottle': return Icons.water_drop_rounded;
      case 'games': return Icons.sports_esports_rounded;
      case 'miniprogram': return Icons.apps_rounded;
      case 'shopping': return Icons.shopping_bag_rounded;
      case 'nearby': return Icons.location_on_rounded;
      default: return Icons.explore_rounded;
    }
  }

  void _onItemTap(String key) {
    switch (key) {
      case 'checkin':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInPage()));
        break;
      case 'official':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OfficialAccountListPage()));
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$key 功能开发中'), duration: const Duration(seconds: 1)));
    }
  }
}
