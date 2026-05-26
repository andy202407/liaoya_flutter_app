import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';
import '../services/api/message_api.dart';
import '../services/api/group_api.dart';
import '../config/api_config.dart';
import '../utils/time_utils.dart';
import 'avatar_widget.dart';

class ChatHistoryGallery extends StatefulWidget {
  final int? friendId;
  final int? groupId;
  final String friendName;
  final bool isMobile;
  final VoidCallback onClose;
  final Function(String fileType, String url, String fileName, int fileSize) onFilePreview;

  const ChatHistoryGallery({
    super.key,
    this.friendId,
    this.groupId,
    this.friendName = '',
    this.isMobile = false,
    required this.onClose,
    required this.onFilePreview,
  });

  @override
  State<ChatHistoryGallery> createState() => _ChatHistoryGalleryState();
}

class _ChatHistoryGalleryState extends State<ChatHistoryGallery>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _messageApi = MessageApi();
  final _groupApi = GroupApi();

  // 每个 tab 独立状态，与 Vue 一致
  final _tabState = <String, _TabState>{
    'media': _TabState(),
    'file': _TabState(),
    'link': _TabState(),
    'text': _TabState(),
  };

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // 消息搜索和日期筛选
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTimeRange? _dateRange;
  Timer? _searchTimer;

  static const _tabs = [
    _TabInfo('影音', Iconsax.gallery, 'media'),
    _TabInfo('文件', Iconsax.document, 'file'),
    _TabInfo('链接', Iconsax.link_1, 'link'),
    _TabInfo('消息', Iconsax.message_text_1, 'text'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadTab('media');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final key = _tabs[_tabController.index].key;
    if (!_tabState[key]!.loaded) {
      _loadTab(key);
    }
    setState(() {}); // 刷新 tab 下划线
  }

  // ─── API 调用 ────────────────────────────────────────────────

  Future<void> _loadTab(String category, {Map<String, dynamic>? extra}) async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final params = extra ?? (category == 'text' ? _buildTextParams() : {});
      final resp = await _callApi(category, limit: category == 'text' ? 20 : 10, extra: params);

      final rawList = (resp['data'] as List?) ?? [];
      final hasMore = resp['has_more'] == true;
      final items = _normalize(rawList, category);

      setState(() {
        _tabState[category]!
          ..items = items
          ..hasMore = hasMore
          ..beforeId = rawList.isNotEmpty ? rawList.last['id'] : null
          ..loaded = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  Future<void> _loadMore() async {
    final key = _tabs[_tabController.index].key;
    final state = _tabState[key]!;
    if (!state.hasMore || _isLoadingMore || _isLoading) return;

    setState(() => _isLoadingMore = true);
    try {
      final params = key == 'text' ? _buildTextParams() : <String, dynamic>{};
      final resp = await _callApi(key, limit: key == 'text' ? 20 : 10, beforeId: state.beforeId, extra: params);

      final rawList = (resp['data'] as List?) ?? [];
      final hasMore = resp['has_more'] == true;
      final more = _normalize(rawList, key);

      setState(() {
        state.items = [...state.items, ...more];
        state.hasMore = hasMore;
        state.beforeId = rawList.isNotEmpty ? rawList.last['id'] : null;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<Map<String, dynamic>> _callApi(String category, {
    int limit = 20,
    dynamic beforeId,
    Map<String, dynamic> extra = const {},
  }) async {
    final params = <String, dynamic>{'limit': limit, 'category': category, ...extra};
    if (beforeId != null) params['before_id'] = beforeId;

    Response resp;
    if (widget.groupId != null) {
      resp = await _groupApi.getGroupMessagesByCategory(
        widget.groupId!, category, limit: limit, beforeId: beforeId, extraParams: extra,
      );
    } else {
      resp = await _messageApi.getMessagesByCategory(
        widget.friendId!, category, limit: limit, beforeId: beforeId, extraParams: extra,
      );
    }
    return resp.data as Map<String, dynamic>;
  }

  // ─── 数据标准化（与 Vue normalizeItems 一致）────────────────────

  List<dynamic> _normalize(List<dynamic> msgs, String category) {
    switch (category) {
      case 'media':
        return msgs.map((m) {
          final type = m['type']?.toString() ?? '';
          final isVideo = type == 'video' || type == 'videos';
          final isAudio = type == 'audio';
          final isMulti = type == 'images' || type == 'videos' || type == 'media';

          String url = m['file_url']?.toString() ?? '';

          // images/videos 字段是 JSON 字符串，需要 decode
          if (url.isEmpty && isMulti) {
            try {
              final imagesRaw = m['images']?.toString() ?? '';
              if (imagesRaw.isNotEmpty) {
                final imgs = jsonDecode(imagesRaw) as List;
                if (imgs.isNotEmpty) url = (imgs[0] is Map ? imgs[0]['url'] : imgs[0]).toString();
              }
            } catch (_) {}
            if (url.isEmpty) {
              try {
                final videosRaw = m['videos']?.toString() ?? '';
                if (videosRaw.isNotEmpty) {
                  final vids = jsonDecode(videosRaw) as List;
                  if (vids.isNotEmpty) url = (vids[0] is Map ? vids[0]['url'] : vids[0]).toString();
                }
              } catch (_) {}
            }
          }

          // thumbnail 是顶层字段（后端 ffmpeg 生成的视频第一帧）
          final rawThumb = m['thumbnail']?.toString() ?? '';
          final thumbnail = rawThumb.isNotEmpty ? _fullUrl(rawThumb) : null;

          return _MediaItem(
            id: m['id'].toString(),
            type: isVideo ? _MType.video : isAudio ? _MType.audio : _MType.image,
            url: _fullUrl(url),
            thumbnail: thumbnail,
            fileName: m['file_name']?.toString() ?? '',
            createdAt: _parseDate(m['created_at']),
            duration: m['duration']?.toString(),
          );
        }).toList();

      case 'file':
        return msgs.map((m) => _FileItem(
          id: m['id'].toString(),
          fileName: m['file_name']?.toString() ?? '未知文件',
          fileSize: (m['file_size'] as num?)?.toInt() ?? 0,
          url: _fullUrl(m['file_url']?.toString() ?? ''),
          createdAt: _parseDate(m['created_at']),
        )).toList();

      case 'link':
        return msgs.map((m) {
          final url = _extractUrl(m['content']?.toString() ?? '');
          return _LinkItem(
            id: m['id'].toString(),
            url: url,
            createdAt: _parseDate(m['created_at']),
          );
        }).where((item) => item.url.isNotEmpty).toList();

      case 'text':
        return msgs.map((m) {
          final from = m['from_user'] as Map<String, dynamic>?;
          return _TextItem(
            id: m['id'].toString(),
            content: m['content']?.toString() ?? '',
            senderName: from?['remark']?.toString() ??
                        from?['nickname']?.toString() ??
                        from?['username']?.toString() ?? '未知',
            senderAvatar: from?['avatar']?.toString() ?? '',
            createdAt: _parseDate(m['created_at']),
          );
        }).toList();

      default:
        return msgs;
    }
  }

  // ─── 辅助 ────────────────────────────────────────────────────

  Map<String, dynamic> _buildTextParams() {
    final p = <String, dynamic>{};
    if (_searchQuery.isNotEmpty) p['keyword'] = _searchQuery;
    if (_dateRange != null) {
      p['date_start'] = _dateRange!.start.toIso8601String().split('T')[0];
      p['date_end'] = _dateRange!.end.toIso8601String().split('T')[0];
    }
    return p;
  }

  String _fullUrl(String url) {
    if (url.isEmpty || url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  String _extractUrl(String content) {
    final m = RegExp(r'https?://[^\s]+').firstMatch(content);
    return m?.group(0) ?? '';
  }

  DateTime _parseDate(dynamic raw) {
    if (raw == null) return TimeUtils.shanghaiNow();
    try { return TimeUtils.parseAsShanghai(raw.toString()); } catch (_) { return TimeUtils.shanghaiNow(); }
  }

  String _fmtDate(DateTime d) => '${d.month}/${d.day}';
  String _fmtFullDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _fmtTime(DateTime d) =>
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  String _fmtSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  void _reloadText() {
    _tabState['text'] = _TabState();
    _loadTab('text');
  }

  // ─── BUILD ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isMobile = widget.isMobile || size.width < 600;

    return Container(
      width: isMobile ? size.width : 520,
      height: isMobile ? size.height : 680,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          _buildHeader(isDark, isMobile),
          _buildTabBar(isDark),
          if (_tabController.index == 3) _buildTextToolbar(isDark),
          Expanded(child: _buildBody(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool isMobile) {
    return Container(
      padding: EdgeInsets.only(
        top: isMobile ? MediaQuery.of(context).padding.top + 14 : 14,
        left: 4, right: 16, bottom: 14,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5,
        )),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            icon: Icon(CupertinoIcons.arrow_left, size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
          Expanded(
            child: Text('聊天记录',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5,
            )),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab = _tabs[i];
              final active = _tabController.index == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tabController.animateTo(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(
                        color: active ? AppColors.primary : Colors.transparent,
                        width: 2,
                      )),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tab.icon, size: 15,
                          color: active ? AppColors.primary
                            : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                        const SizedBox(width: 5),
                        Text(tab.label,
                          style: TextStyle(fontSize: 13,
                            color: active ? AppColors.primary
                              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          )),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildTextToolbar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(
          color: isDark ? AppColors.darkDivider : AppColors.lightDivider, width: 0.5,
        )),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 34,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText),
              decoration: InputDecoration(
                hintText: '搜索消息内容...',
                hintStyle: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                prefixIcon: Icon(Iconsax.search_normal_1, size: 15,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(
                  onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); _reloadText(); },
                  child: Icon(Iconsax.close_circle, size: 15,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ) : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                _searchTimer?.cancel();
                _searchTimer = Timer(const Duration(milliseconds: 400), _reloadText);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showDatePicker,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _dateRange != null
                ? AppColors.primary.withValues(alpha: 0.15)
                : (isDark ? AppColors.darkInputBg : AppColors.lightInputBg),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Iconsax.calendar_1, size: 18,
              color: _dateRange != null ? AppColors.primary
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildMediaGrid(isDark),
        _buildFileList(isDark),
        _buildLinkList(isDark),
        _buildTextList(isDark),
      ],
    );
  }

  // ─── 影音网格 ─────────────────────────────────────────────────

  Widget _buildMediaGrid(bool isDark) {
    final items = _tabState['media']!.items.cast<_MediaItem>();

    if (_isLoading && items.isEmpty) return _buildLoading();
    if (_errorMessage != null && items.isEmpty) return _buildError(_errorMessage!);
    if (items.isEmpty) return _buildEmpty('暂无影音内容', Iconsax.gallery);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n is ScrollEndNotification && n.metrics.extentAfter < 100) _loadMore(); return false; },
      child: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 3, mainAxisSpacing: 3,
        ),
        itemCount: items.length + (_isLoadingMore ? 3 : 0),
        itemBuilder: (context, i) {
          if (i >= items.length) return _buildShimmerBox(isDark);
          return _buildMediaCell(items[i], isDark);
        },
      ),
    );
  }

  Widget _buildMediaCell(_MediaItem item, bool isDark) {
    return GestureDetector(
      onTap: () {
        if (item.type == _MType.video) {
          widget.onFilePreview('video', item.url, item.fileName, 0);
        } else {
          widget.onFilePreview('image', item.url, item.fileName, 0);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(fit: StackFit.expand, children: [
          // 视频优先用 thumbnail，没有则显示占位底色
          if (item.thumbnail != null)
            CachedNetworkImage(
              imageUrl: item.thumbnail!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: isDark ? AppColors.darkInputBg : const Color(0xFFE5E5EA)),
              errorWidget: (_, __, ___) => _videoPlaceholder(isDark),
            )
          else if (item.type == _MType.image)
            CachedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: isDark ? AppColors.darkInputBg : const Color(0xFFE5E5EA)),
              errorWidget: (_, __, ___) => Container(
                color: isDark ? AppColors.darkInputBg : const Color(0xFFE5E5EA),
                child: Icon(Iconsax.image, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
              ),
            )
          else
            // 视频但没有缩略图
            _videoPlaceholder(isDark),
          if (item.type == _MType.video) ...[
            Container(color: Colors.black26),
            const Center(child: Icon(CupertinoIcons.play_circle_fill, color: Colors.white, size: 32)),
            if (item.duration != null)
              Positioned(bottom: 4, right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                  child: Text(item.duration!, style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
          if (item.type == _MType.audio)
            const Center(child: Icon(CupertinoIcons.waveform, color: Colors.white, size: 28)),
          // 日期浮层
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                ),
              ),
              child: Text(_fmtDate(item.createdAt),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
                textAlign: TextAlign.right),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── 文件列表 ─────────────────────────────────────────────────

  Widget _buildFileList(bool isDark) {
    final items = _tabState['file']!.items.cast<_FileItem>();

    if (_isLoading && items.isEmpty) return _buildLoading();
    if (_errorMessage != null && items.isEmpty) return _buildError(_errorMessage!);
    if (items.isEmpty) return _buildEmpty('暂无文档文件', Iconsax.document);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n is ScrollEndNotification && n.metrics.extentAfter < 100) _loadMore(); return false; },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator()));
          return _buildFileRow(items[i], isDark);
        },
      ),
    );
  }

  Widget _buildFileRow(_FileItem item, bool isDark) {
    final color = _fileColor(item.fileName);
    return InkWell(
      onTap: () => widget.onFilePreview('file', item.url, item.fileName, item.fileSize),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(_fileIcon(item.fileName), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.fileName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkText : AppColors.lightText),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 2),
            Row(children: [
              Text(_fmtSize(item.fileSize),
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              Text(' · ', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              Text(_fmtFullDate(item.createdAt),
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
            ]),
          ])),
          IconButton(
            onPressed: () => _downloadFile(item),
            icon: Icon(Iconsax.import, size: 18, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
          ),
        ]),
      ),
    );
  }

  // ─── 链接列表 ─────────────────────────────────────────────────

  Widget _buildLinkList(bool isDark) {
    final items = _tabState['link']!.items.cast<_LinkItem>();

    if (_isLoading && items.isEmpty) return _buildLoading();
    if (_errorMessage != null && items.isEmpty) return _buildError(_errorMessage!);
    if (items.isEmpty) return _buildEmpty('暂无链接记录', Iconsax.link_1);

    return NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n is ScrollEndNotification && n.metrics.extentAfter < 100) _loadMore(); return false; },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator()));
          return _buildLinkRow(items[i], isDark);
        },
      ),
    );
  }

  Widget _buildLinkRow(_LinkItem item, bool isDark) {
    return InkWell(
      onTap: () => _openLink(item.url),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Iconsax.link_1, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.url,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
              overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 2),
            Text(_fmtFullDate(item.createdAt),
              style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
          ])),
          Icon(Iconsax.export_1, size: 16, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
        ]),
      ),
    );
  }

  // ─── 消息列表 ─────────────────────────────────────────────────

  Widget _buildTextList(bool isDark) {
    final items = _tabState['text']!.items.cast<_TextItem>();

    if (_isLoading && items.isEmpty) return _buildLoading();
    if (_errorMessage != null && items.isEmpty) return _buildError(_errorMessage!);
    if (items.isEmpty) {
      final msg = (_searchQuery.isNotEmpty || _dateRange != null) ? '未找到匹配消息' : '暂无文字消息';
      return _buildEmpty(msg, Iconsax.message_text_1);
    }

    // 按日期分组，保持顺序
    final groups = <String, List<_TextItem>>{};
    for (final item in items) {
      final key = _fmtFullDate(item.createdAt);
      (groups[key] ??= []).add(item);
    }
    final dateKeys = groups.keys.toList();

    // 构建扁平列表：日期 header + 消息行交替排列
    final flatItems = <_FlatListItem>[];
    for (final date in dateKeys) {
      flatItems.add(_FlatListItem(isHeader: true, date: date));
      for (final item in groups[date]!) {
        flatItems.add(_FlatListItem(isHeader: false, textItem: item));
      }
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) { if (n is ScrollEndNotification && n.metrics.extentAfter < 100) _loadMore(); return false; },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: flatItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= flatItems.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CupertinoActivityIndicator()));
          }
          final item = flatItems[i];
          if (item.isHeader) {
            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(item.date!,
                  style: TextStyle(fontSize: 11,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ),
            );
          }
          return _buildTextRow(item.textItem!, isDark);
        },
      ),
    );
  }

  Widget _buildTextRow(_TextItem item, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AvatarWidget(url: item.senderAvatar, name: item.senderName, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkInputBg : AppColors.lightInputBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item.senderName,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkText : AppColors.lightText))),
                Text(_fmtTime(item.createdAt),
                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
              ]),
              const SizedBox(height: 4),
              _buildHighlightedText(item.content, isDark),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHighlightedText(String content, bool isDark) {
    if (_searchQuery.isEmpty) {
      return Text(content, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText));
    }
    final spans = <TextSpan>[];
    final lower = content.toLowerCase();
    final kw = _searchQuery.toLowerCase();
    int start = 0;
    while (true) {
      final idx = lower.indexOf(kw, start);
      if (idx < 0) {
        spans.add(TextSpan(text: content.substring(start)));
        break;
      }
      if (idx > start) spans.add(TextSpan(text: content.substring(start, idx)));
      spans.add(TextSpan(
        text: content.substring(idx, idx + kw.length),
        style: const TextStyle(backgroundColor: Color(0xFFFFE066), color: Colors.black, fontWeight: FontWeight.w600),
      ));
      start = idx + kw.length;
    }
    return RichText(text: TextSpan(
      style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText),
      children: spans,
    ));
  }

  // ─── 文件图标 ─────────────────────────────────────────────────

  IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg','jpeg','png','gif','webp','heic'].contains(ext)) return Iconsax.image;
    if (['mp4','mov','avi','mkv'].contains(ext)) return Iconsax.video;
    if (ext == 'pdf') return Iconsax.document_text;
    if (['xls','xlsx'].contains(ext)) return Iconsax.document_sketch;
    if (['doc','docx'].contains(ext)) return Iconsax.document_text_1;
    if (['ppt','pptx'].contains(ext)) return Iconsax.document_sketch;
    if (['zip','rar','7z','tar','gz'].contains(ext)) return Iconsax.folder;
    return Iconsax.document;
  }

  Color _fileColor(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (ext == 'pdf') return AppColors.error;
    if (['xls','xlsx'].contains(ext)) return AppColors.success;
    if (['doc','docx'].contains(ext)) return AppColors.info;
    if (['ppt','pptx'].contains(ext)) return AppColors.warning;
    if (['zip','rar','7z'].contains(ext)) return AppColors.warning;
    if (['mp4','mov','avi'].contains(ext)) return AppColors.primary;
    return AppColors.darkTextTertiary;
  }

  // ─── 空/加载/错误状态 ─────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(child: CupertinoActivityIndicator());
  }

  Widget _buildError(String msg) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(CupertinoIcons.exclamationmark_circle, size: 40, color: AppColors.error),
        const SizedBox(height: 12),
        Text(msg, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.error)),
        const SizedBox(height: 12),
        CupertinoButton(
          onPressed: () => _loadTab(_tabs[_tabController.index].key),
          child: const Text('重试'),
        ),
      ]),
    ));
  }

  Widget _buildEmpty(String msg, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 40, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
      const SizedBox(height: 10),
      Text(msg, style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
    ]));
  }

  Widget _videoPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF2A2A35) : const Color(0xFFD1D1D6),
      child: const Center(
        child: Icon(CupertinoIcons.film, color: Colors.white54, size: 28),
      ),
    );
  }

  Widget _buildShimmerBox(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkInputBg : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // ─── 操作 ─────────────────────────────────────────────────────

  void _downloadFile(_FileItem item) async {
    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${item.fileName}';
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DownloadDialog(url: item.url, savePath: savePath, fileName: item.fileName),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('下载失败: $e')));
    }
  }

  void _openLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _reloadText();
    }
  }
}

// ─── 数据模型 ─────────────────────────────────────────────────

class _TabState {
  List<dynamic> items = [];
  bool hasMore = false;
  dynamic beforeId;
  bool loaded = false;
}

class _TabInfo {
  final String label;
  final IconData icon;
  final String key;
  const _TabInfo(this.label, this.icon, this.key);
}

enum _MType { image, video, audio }

class _MediaItem {
  final String id, url, fileName;
  final _MType type;
  final String? thumbnail, duration;
  final DateTime createdAt;
  _MediaItem({required this.id, required this.type, required this.url,
    this.thumbnail, required this.fileName, required this.createdAt, this.duration});
}

class _FileItem {
  final String id, fileName, url;
  final int fileSize;
  final DateTime createdAt;
  _FileItem({required this.id, required this.fileName, required this.fileSize,
    required this.url, required this.createdAt});
}

class _LinkItem {
  final String id, url;
  final DateTime createdAt;
  _LinkItem({required this.id, required this.url, required this.createdAt});
}

class _TextItem {
  final String id, content, senderName, senderAvatar;
  final DateTime createdAt;
  _TextItem({required this.id, required this.content, required this.senderName,
    required this.senderAvatar, required this.createdAt});
}

// ─── 消息列表扁平化辅助 ──────────────────────────────────────

class _FlatListItem {
  final bool isHeader;
  final String? date;
  final _TextItem? textItem;
  _FlatListItem({required this.isHeader, this.date, this.textItem});
}

// ─── 下载对话框 ───────────────────────────────────────────────

class _DownloadDialog extends StatefulWidget {
  final String url, savePath, fileName;
  const _DownloadDialog({required this.url, required this.savePath, required this.fileName});
  @override State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progress = 0;
  bool _done = false;
  String? _error;

  @override
  void initState() { super.initState(); _start(); }

  Future<void> _start() async {
    try {
      await Dio().download(widget.url, widget.savePath,
        onReceiveProgress: (got, total) {
          if (total > 0 && mounted) setState(() => _progress = got / total);
        });
      if (mounted) setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      title: Text(_error != null ? '下载失败' : _done ? '下载完成' : '正在下载'),
      content: _error != null
        ? Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))
        : Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: _done ? 1.0 : _progress, color: AppColors.primary),
            const SizedBox(height: 8),
            Text('${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 13)),
          ]),
      actions: [
        if (_error != null || _done)
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('关闭')),
      ],
    );
  }
}
