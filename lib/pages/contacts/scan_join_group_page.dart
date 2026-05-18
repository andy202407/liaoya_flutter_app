import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../services/api/group_api.dart';
import '../../providers/conversation_provider.dart';
import '../../theme/app_colors.dart';

class ScanJoinGroupPage extends StatefulWidget {
  const ScanJoinGroupPage({super.key});

  @override
  State<ScanJoinGroupPage> createState() => _ScanJoinGroupPageState();
}

class _ScanJoinGroupPageState extends State<ScanJoinGroupPage> {
  final _codeController = TextEditingController();
  final _groupApi = GroupApi();
  bool _isProcessing = false;
  bool _showManualInput = false;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _joinByCode(String code) async {
    if (_isProcessing || code.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final response = await _groupApi.joinByInviteCode(code);
      final data = response.data;
      if (data['success'] == true && mounted) {
        final groupId = data['group_id'];
        final msg = data['message'] ?? '加入群聊成功';

        if (mounted) {
          context.read<ConversationProvider>().loadConversations();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        if (groupId != null && mounted) {
          Navigator.pop(context, groupId);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = '';
        if (e is DioException && e.response != null) {
          errorMsg = e.response?.data?['message'] ?? '';
        }
        if (errorMsg.isEmpty) errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _joinByToken(String token) async {
    if (_isProcessing || token.isEmpty) return;
    setState(() => _isProcessing = true);

    try {
      final response = await _groupApi.joinByLink(token);
      final data = response.data;
      if (data['success'] == true && mounted) {
        final groupId = data['group_id'];
        final msg = data['message'] ?? '加入群聊成功';

        if (mounted) {
          context.read<ConversationProvider>().loadConversations();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );

        if (groupId != null && mounted) {
          Navigator.pop(context, groupId);
        }
      } else if (data['require_invite_code'] == true && mounted) {
        // 需要输入邀请码
        _scannerController?.stop();
        _showInviteCodeDialog(token);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = '';
        if (e is DioException && e.response != null) {
          final respData = e.response?.data;
          errorMsg = respData?['message'] ?? '';
          // 需要邀请码
          if (respData?['require_invite_code'] == true) {
            _showInviteCodeDialog(token);
            if (mounted) setState(() => _isProcessing = false);
            return;
          }
        }
        if (errorMsg.isEmpty) errorMsg = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }

    if (mounted) setState(() => _isProcessing = false);
  }

  void _showInviteCodeDialog(String token) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入邀请码'),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 6, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: '6位数字邀请码', counterText: ''),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              try {
                final response = await _groupApi.joinByLink(token, code: code);
                final data = response.data;
                if (data['success'] == true && mounted) {
                  final groupId = data['group_id'];
                  context.read<ConversationProvider>().loadConversations();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(data['message'] ?? '加入群聊成功')),
                  );
                  if (groupId != null && mounted) Navigator.pop(context, groupId);
                }
              } catch (e) {
                if (mounted) {
                  String msg = '';
                  if (e is DioException && e.response != null) {
                    msg = e.response?.data?['message'] ?? '';
                  }
                  if (msg.isEmpty) msg = '加入失败';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
              if (mounted) setState(() => _isProcessing = false);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final value = barcode.rawValue!;

    // 支持格式: qiaoliao://group/join?token=xxx (邀请链接)
    if (value.contains('group/join') && value.contains('token=')) {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        final token = uri.queryParameters['token'];
        if (token != null && token.isNotEmpty) {
          _scannerController?.stop();
          _joinByToken(token);
          return;
        }
      }
    }

    // 支持格式: qiaoliao://group/join?code=xxx (邀请码)
    if (value.startsWith('qiaoliao://group/join')) {
      final uri = Uri.tryParse(value);
      if (uri != null) {
        final code = uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          _scannerController?.stop();
          _joinByCode(code);
          return;
        }
      }
    }

    // 支持纯6位数字（邀请码）
    if (RegExp(r'^\d{6}$').hasMatch(value)) {
      _scannerController?.stop();
      _joinByCode(value);
      return;
    }

    // 无法识别
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('无法识别的二维码: ${value.length > 50 ? '${value.substring(0, 50)}...' : value}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫一扫加入群聊'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showManualInput = !_showManualInput),
            child: Text(
              _showManualInput ? '扫码' : '输入口令',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_showManualInput)
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController!,
                    onDetect: _onDetect,
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Text(
                      '将二维码放入框内自动扫描',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_showManualInput)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dialpad_rounded, size: 48, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      '输入群聆6位数字口令',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _joinByCode(_codeController.text.trim()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('加入群聊', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}