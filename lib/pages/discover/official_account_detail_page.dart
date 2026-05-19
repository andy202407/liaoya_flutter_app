import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api/api_client.dart';
import '../../config/api_config.dart';
import '../../theme/app_colors.dart';
import '../../widgets/avatar_widget.dart';

class OfficialAccountDetailPage extends StatefulWidget {
  final Map<String, dynamic> account;
  const OfficialAccountDetailPage({super.key, required this.account});

  @override
  State<OfficialAccountDetailPage> createState() => _OfficialAccountDetailPageState();
}

class _OfficialAccountDetailPageState extends State<OfficialAccountDetailPage> {
  final _dio = ApiClient.instance.dio;
  List<Map<String, dynamic>> _articles = [];
  bool _isLoading = true;
  Map<String, dynamic>? _viewingArticle;

  String get _name => widget.account['name'] as String? ?? '公众号';
  String? get _avatar => widget.account['avatar'] as String?;
  String get _desc => widget.account['description'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final id = widget.account['id'];
      final res = await _dio.get('/user/official-accounts/$id/articles', queryParameters: {'page': 1, 'limit': 20});
      if (res.data['success'] == true) {
        final data = res.data['data'] as Map<String, dynamic>? ?? {};
        final List<dynamic> articles = data['articles'] ?? [];
        setState(() {
          _articles = articles.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('[OfficialAccountDetail] error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openArticle(Map<String, dynamic> article) async {
    try {
      final articleId = article['id'];
      final res = await _dio.get('/user/official-accounts/articles/$articleId');
      if (res.data['success'] == true) {
        setState(() => _viewingArticle = res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  Future<void> _likeArticle() async {
    if (_viewingArticle == null) return;
    final liked = _viewingArticle!['_liked'] == true;
    final newLiked = !liked;
    try {
      final articleId = _viewingArticle!['id'];
      await _dio.post('/user/official-accounts/articles/$articleId/like', data: {'like': newLiked});
      setState(() {
        _viewingArticle = {
          ..._viewingArticle!,
          '_liked': newLiked,
          'likes': ((_viewingArticle!['likes'] as int?) ?? 0) + (newLiked ? 1 : -1),
        };
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_viewingArticle != null) return _buildArticleView(context);
    return _buildArticleList(context);
  }

  Widget _buildArticleList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(url: _avatar, name: _name, size: 28),
            const SizedBox(width: 8),
            Flexible(child: Text(_name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _articles.isEmpty
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.article_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 12),
                    Text('暂无文章', style: TextStyle(color: isDark ? Colors.white38 : Colors.black38)),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _loadArticles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _articles.length,
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      final title = article['title'] as String? ?? '';
                      final summary = article['summary'] as String? ?? '';
                      final cover = article['cover_image'] as String? ?? '';
                      final time = article['created_at'] as String? ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openArticle(article),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (cover.isNotEmpty)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: CachedNetworkImage(
                                    imageUrl: cover.startsWith('http') ? cover : '${ApiConfig.baseUrl}$cover',
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                                    if (summary.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54)),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(_formatTime(time), style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildArticleView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _viewingArticle!['title'] as String? ?? '';
    final content = _viewingArticle!['content'] as String? ?? '';
    final likes = _viewingArticle!['likes'] as int? ?? 0;
    final liked = _viewingArticle!['_liked'] == true;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _viewingArticle = null),
        ),
        title: Text(_name),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            HtmlWidget(
              content,
              textStyle: TextStyle(fontSize: 15, height: 1.7, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 24),
            // 点赞按钮
            Center(
              child: GestureDetector(
                onTap: _likeArticle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: liked ? AppColors.primary.withAlpha(20) : (isDark ? Colors.white12 : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: liked ? AppColors.primary : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18, color: liked ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45)),
                      const SizedBox(width: 6),
                      Text('$likes', style: TextStyle(color: liked ? AppColors.primary : (isDark ? Colors.white54 : Colors.black45))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timeStr) {
    if (timeStr.isEmpty) return '';
    try {
      final time = DateTime.parse(timeStr);
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
