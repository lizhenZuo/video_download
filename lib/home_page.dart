import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'models/download_models.dart';
import 'services/download_support.dart';
import 'services/video_download_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _urlController = TextEditingController();
  final VideoDownloadService _service = VideoDownloadService();

  VideoExtractionResult? _result;
  DownloadReceipt? _lastDownload;
  String? _errorMessage;
  bool _isExtracting = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _downloadLabel;
  String? _downloadingAssetId;
  bool _isSavingToGallery = false;
  bool _isSharing = false;

  bool get _supportsDirectOpen => !Platform.isIOS;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _pasteUrl() async {
    final clipboard = await Clipboard.getData('text/plain');
    final text = clipboard?.text?.trim();
    if (text == null || text.isEmpty) {
      return;
    }

    setState(() {
      _urlController.text = text;
    });
  }

  Future<void> _extractVideo() async {
    FocusScope.of(context).unfocus();

    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = '先粘贴一个视频链接。';
      });
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _result = null;
      _lastDownload = null;
    });

    try {
      final result = await _service.extract(_urlController.text);
      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _downloadAsset(DownloadAsset asset) async {
    final result = _result;
    if (result == null || _isDownloading) {
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadLabel = asset.title;
      _downloadingAssetId = asset.id;
      _errorMessage = null;
    });

    try {
      final receipt = await _service.downloadAsset(
        asset,
        videoTitle: result.title,
        onProgress: (progress) {
          if (!mounted) {
            return;
          }
          setState(() {
            _downloadProgress = progress.clamp(0, 1);
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastDownload = receipt;
      });

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已保存到 ${receipt.fileName}'),
            action: _supportsDirectOpen
                ? SnackBarAction(
                    label: '打开',
                    onPressed: _openLastDownload,
                  )
                : null,
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '下载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadLabel = null;
          _downloadingAssetId = null;
        });
      }
    }
  }

  Future<void> _openLastDownload() async {
    final receipt = _lastDownload;
    if (receipt == null) {
      return;
    }

    final result = await OpenFilex.open(receipt.filePath);
    if (!mounted) {
      return;
    }

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法直接打开文件：${result.message}')),
      );
    }
  }

  Future<void> _saveLastDownloadToGallery() async {
    final receipt = _lastDownload;
    if (receipt == null || !receipt.canSaveToGallery || _isSavingToGallery) {
      return;
    }

    setState(() {
      _isSavingToGallery = true;
      _errorMessage = null;
    });

    try {
      if (receipt.isVideo) {
        await Gal.putVideo(receipt.filePath);
      } else {
        await Gal.putImage(receipt.filePath);
      }

      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              Platform.isIOS ? '已保存到系统相册，请到“照片”App 查看' : '已保存到系统相册',
            ),
          ),
        );
    } on GalException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '保存到相册失败：${_mapGalleryError(error)}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '保存到相册失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToGallery = false;
        });
      }
    }
  }

  Future<void> _shareLastDownload(BuildContext anchorContext) async {
    final receipt = _lastDownload;
    if (receipt == null || _isSharing) {
      return;
    }

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      final box = anchorContext.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          title: receipt.fileName,
          subject: receipt.fileName,
          text: '分享文件：${receipt.fileName}',
          files: [XFile(receipt.filePath)],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '分享失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  String _mapGalleryError(GalException error) {
    return switch (error.type) {
      GalExceptionType.accessDenied => '没有相册权限，请在系统设置里允许访问照片。',
      GalExceptionType.notEnoughSpace => '设备剩余空间不足。',
      GalExceptionType.notSupportedFormat => '当前文件格式不支持保存到系统相册。',
      GalExceptionType.unexpected => '系统相册返回了未知错误。',
    };
  }

  Future<void> _openSettings() async {
    final cacheCleared = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const _SettingsPage(),
      ),
    );

    if (!mounted || cacheCleared != true) {
      return;
    }

    setState(() {
      _lastDownload = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D355C),
              Color(0xFF0D355C),
              Color(0xFFF7F2E8),
            ],
            stops: [0, 0.28, 0.28],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openSettings,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.settings_rounded, size: 18),
                    label: const Text(
                      '设置中心',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _HeroSection(
                  isExtracting: _isExtracting,
                  isDownloading: _isDownloading,
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '解析视频',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10273F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '统一处理 YouTube、抖音，以及 iiilab / SnapAny 当前公开支持的 TikTok、Bilibili、Twitter、Instagram、Facebook、Vimeo、Threads 等平台链接。',
                          style: TextStyle(
                            color: Color(0xFF4D6172),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _urlController,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText:
                                '粘贴视频链接，例如 YouTube、抖音、TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo...',
                            suffixIcon: IconButton(
                              tooltip: '粘贴剪贴板',
                              onPressed: _pasteUrl,
                              icon: const Icon(Icons.content_paste_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isExtracting ? null : _extractVideo,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE66A3B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                icon: _isExtracting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_downward_rounded),
                                label: Text(_isExtracting ? '解析中...' : '解析视频'),
                              ),
                            ),
                          ],
                        ),
                        if (_isDownloading) ...[
                          const SizedBox(height: 16),
                          _DownloadProgress(
                            label: _downloadLabel ?? '正在下载',
                            progress: _downloadProgress,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _MessageCard(
                    backgroundColor: const Color(0xFFFFE9E3),
                    foregroundColor: const Color(0xFF8A2A17),
                    icon: Icons.error_outline_rounded,
                    message: _errorMessage!,
                  ),
                ],
                if (_lastDownload != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xFFE1F4EB),
                                foregroundColor: Color(0xFF1C7D52),
                                child: Icon(Icons.check_circle_outline_rounded),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _lastDownload!.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10273F),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _lastDownload!.filePath,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF54697A),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              if (_supportsDirectOpen)
                                FilledButton.tonal(
                                  onPressed: _openLastDownload,
                                  child: const Text('打开'),
                                ),
                              if (_lastDownload!.canSaveToGallery)
                                FilledButton.tonalIcon(
                                  onPressed: _isSavingToGallery
                                      ? null
                                      : _saveLastDownloadToGallery,
                                  icon: _isSavingToGallery
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.photo_library_outlined),
                                  label: Text(
                                    _isSavingToGallery ? '保存中...' : '保存到相册',
                                  ),
                                ),
                              Builder(
                                builder: (buttonContext) {
                                  return FilledButton.tonalIcon(
                                    onPressed: _isSharing
                                        ? null
                                        : () =>
                                            _shareLastDownload(buttonContext),
                                    icon: _isSharing
                                        ? const SizedBox.square(
                                            dimension: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.share_outlined),
                                    label: Text(_isSharing ? '分享中...' : '分享'),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 16),
                  _ResultPanel(
                    result: _result!,
                    onDownload: _downloadAsset,
                    downloadingAssetId: _downloadingAssetId,
                    downloadProgress: _downloadProgress,
                  ),
                ],
                const SizedBox(height: 16),
                const _FooterNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isExtracting,
    required this.isDownloading,
  });

  final bool isExtracting;
  final bool isDownloading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF113B69),
            Color(0xFF1B5B8B),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroChip('YouTube + 抖音 + 多平台'),
              _heroChip(isExtracting || isDownloading ? '进行中' : '可直接运行'),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Tube Fetch',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '把链接粘进来，解析封面和可下载的视频、音频、图片或分享页直链，支持保存到本地、相册和系统分享。',
            style: TextStyle(
              color: Color(0xFFD9E7F5),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.result,
    required this.onDownload,
    required this.downloadingAssetId,
    required this.downloadProgress,
  });

  final VideoExtractionResult result;
  final ValueChanged<DownloadAsset> onDownload;
  final String? downloadingAssetId;
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _RemotePreviewImage(
                  url: result.thumbnailUrl,
                  headers: result.thumbnailHeaders,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              result.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF10273F),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetaPill(
                  icon: Icons.link_rounded,
                  label: result.platformLabel,
                ),
                _MetaPill(
                  icon: Icons.person_outline_rounded,
                  label: result.author,
                ),
                if (result.duration != null)
                  _MetaPill(
                    icon: Icons.schedule_rounded,
                    label: _formatDuration(result.duration!),
                  ),
                _MetaPill(
                  icon: Icons.play_circle_outline_rounded,
                  label: result.primaryMetricLabel,
                ),
              ],
            ),
            if (result.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                result.description,
                style: const TextStyle(
                  color: Color(0xFF4D6172),
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 18),
            const _SectionTitle(
              title: '快速下载',
              subtitle: '最常用的下载项，会根据平台能力自动变化。',
            ),
            const SizedBox(height: 12),
            _AssetGrid(
              assets: result.quickActions,
              onTap: onDownload,
              downloadingAssetId: downloadingAssetId,
              downloadProgress: downloadProgress,
            ),
            if (result.muxedOptions.isNotEmpty) ...[
              const SizedBox(height: 22),
              const _SectionTitle(
                title: '可直接播放的视频流',
                subtitle: '带音轨，下载后可直接打开。',
              ),
              const SizedBox(height: 12),
              _AssetGrid(
                assets: result.muxedOptions,
                onTap: onDownload,
                downloadingAssetId: downloadingAssetId,
                downloadProgress: downloadProgress,
              ),
            ],
            if (result.audioOptions.isNotEmpty) ...[
              const SizedBox(height: 22),
              const _SectionTitle(
                title: '独立音频流',
                subtitle: '适合只保留声音或后续单独合并。',
              ),
              const SizedBox(height: 12),
              _AssetGrid(
                assets: result.audioOptions,
                onTap: onDownload,
                downloadingAssetId: downloadingAssetId,
                downloadProgress: downloadProgress,
              ),
            ],
            if (result.videoOnlyOptions.isNotEmpty) ...[
              const SizedBox(height: 22),
              const _SectionTitle(
                title: '高分辨率视频流',
                subtitle: '常见为 1080p / 4K，但不带音轨。',
              ),
              const SizedBox(height: 12),
              _AssetGrid(
                assets: result.videoOnlyOptions,
                onTap: onDownload,
                downloadingAssetId: downloadingAssetId,
                downloadProgress: downloadProgress,
              ),
            ],
            if (result.imageOptions.isNotEmpty) ...[
              const SizedBox(height: 22),
              const _SectionTitle(
                title: '图片 / 封面下载',
                subtitle: '图集原图、封面图会统一放在这里。',
              ),
              const SizedBox(height: 12),
              _AssetGrid(
                assets: result.imageOptions,
                onTap: onDownload,
                downloadingAssetId: downloadingAssetId,
                downloadProgress: downloadProgress,
              ),
            ],
            if (result.warning != null) ...[
              const SizedBox(height: 18),
              _MessageCard(
                backgroundColor: const Color(0xFFFFF2D8),
                foregroundColor: const Color(0xFF7A4D04),
                icon: Icons.info_outline_rounded,
                message: result.warning!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  int? _cacheBytes;
  bool _isLoadingCacheSize = true;
  bool _isClearingCache = false;
  bool _cacheCleared = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  Future<void> _refreshCacheSize() async {
    final cacheBytes = await measureAppCacheBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _cacheBytes = cacheBytes;
      _isLoadingCacheSize = false;
    });
  }

  Future<void> _clearCache() async {
    if (_isClearingCache) {
      return;
    }

    final cacheBytes = _cacheBytes ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('清空缓存'),
          content: Text(
            cacheBytes > 0
                ? '当前缓存约 ${_formatStorageSize(cacheBytes)}。清空后，App 内已下载但未另存到系统相册的位置文件会被删除。'
                : '当前没有可清理的缓存。仍然继续刷新缓存状态吗？',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(cacheBytes > 0 ? '清空' : '刷新'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isClearingCache = true;
    });

    try {
      final clearedBytes = cacheBytes > 0 ? await clearAppCache() : 0;
      if (!mounted) {
        return;
      }

      setState(() {
        _cacheBytes = 0;
        _cacheCleared = _cacheCleared || clearedBytes > 0;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              clearedBytes > 0
                  ? '已清空 ${_formatStorageSize(clearedBytes)} 缓存'
                  : '当前没有可清理的缓存',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('清空缓存失败：$error')),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
          _isLoadingCacheSize = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheLabel = _isLoadingCacheSize
        ? '正在计算...'
        : _formatStorageSize(_cacheBytes ?? 0);

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(_cacheCleared);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('设置中心'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(_cacheCleared),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                onTap: (_isLoadingCacheSize || _isClearingCache)
                    ? null
                    : _clearCache,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: const Text(
                  '缓存大小',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10273F),
                  ),
                ),
                subtitle: Text(
                  _isClearingCache
                      ? '正在清空 App 缓存...'
                      : '点击后可清空 App 内下载目录中的缓存文件。',
                  style: const TextStyle(height: 1.45),
                ),
                trailing: _isLoadingCacheSize
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : Text(
                        cacheLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE66A3B),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '这里清理的是 App 管理目录里的下载文件，不会影响你已经保存到系统相册或通过系统分享出去的副本。',
              style: TextStyle(
                color: Color(0xFF54697A),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemotePreviewImage extends StatefulWidget {
  const _RemotePreviewImage({
    required this.url,
    this.headers,
  });

  final Uri url;
  final Map<String, String>? headers;

  @override
  State<_RemotePreviewImage> createState() => _RemotePreviewImageState();
}

class _RemotePreviewImageState extends State<_RemotePreviewImage> {
  Future<Uint8List>? _imageBytesFuture;

  @override
  void initState() {
    super.initState();
    _imageBytesFuture = _loadImageBytes();
  }

  @override
  void didUpdateWidget(covariant _RemotePreviewImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        !_sameHeaders(oldWidget.headers, widget.headers)) {
      _imageBytesFuture = _loadImageBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _imageBytesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: const Color(0xFFE6EDF3),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          );
        }

        return _buildFailedPlaceholder();
      },
    );
  }

  Future<Uint8List> _loadImageBytes() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);

    try {
      final request = await client.getUrl(widget.url);
      widget.headers?.forEach((key, value) {
        request.headers.set(key, value);
      });

      final response = await request.close().timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Image request failed with status ${response.statusCode}',
          uri: widget.url,
        );
      }

      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.add(chunk);
      }

      final imageBytes = bytes.takeBytes();
      if (imageBytes.isEmpty) {
        throw const FileSystemException('Image response was empty');
      }

      return imageBytes;
    } finally {
      client.close(force: true);
    }
  }

  bool _sameHeaders(
    Map<String, String>? left,
    Map<String, String>? right,
  ) {
    return mapEquals(left, right);
  }

  Widget _buildFailedPlaceholder() {
    return Container(
      color: const Color(0xFFE6EDF3),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF5D7284),
            size: 34,
          ),
          SizedBox(height: 10),
          Text(
            '封面加载失败',
            style: TextStyle(
              color: Color(0xFF5D7284),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatStorageSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  final formatted = value >= 100 || unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  return '$formatted ${units[unitIndex]}';
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.onTap,
    required this.downloadingAssetId,
    required this.downloadProgress,
  });

  final List<DownloadAsset> assets;
  final ValueChanged<DownloadAsset> onTap;
  final String? downloadingAssetId;
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        final width =
            isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final asset in assets)
              SizedBox(
                width: width,
                child: _AssetCard(
                  asset: asset,
                  onTap: () => onTap(asset),
                  isDownloading: downloadingAssetId == asset.id,
                  downloadProgress: downloadProgress,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AssetCard extends StatelessWidget {
  const _AssetCard({
    required this.asset,
    required this.onTap,
    required this.isDownloading,
    required this.downloadProgress,
  });

  final DownloadAsset asset;
  final VoidCallback onTap;
  final bool isDownloading;
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    final accent = switch (asset.kind) {
      DownloadAssetKind.muxedVideo => const Color(0xFF0F6CBA),
      DownloadAssetKind.audioOnly => const Color(0xFFCB5D2C),
      DownloadAssetKind.videoOnly => const Color(0xFF334B65),
      DownloadAssetKind.image => const Color(0xFF2E8B57),
      DownloadAssetKind.thumbnail => const Color(0xFF2E8B57),
    };

    final icon = switch (asset.kind) {
      DownloadAssetKind.muxedVideo => Icons.movie_creation_outlined,
      DownloadAssetKind.audioOnly => Icons.headphones_outlined,
      DownloadAssetKind.videoOnly => Icons.high_quality_outlined,
      DownloadAssetKind.image => Icons.collections_outlined,
      DownloadAssetKind.thumbnail => Icons.image_outlined,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.12),
                  foregroundColor: accent,
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    asset.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10273F),
                    ),
                  ),
                ),
                if (asset.requiresMuxing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF2D8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      '无音轨',
                      style: TextStyle(
                        color: Color(0xFF7A4D04),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              asset.subtitle,
              style: const TextStyle(
                color: Color(0xFF54697A),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (isDownloading) ...[
              Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      value: downloadProgress > 0 ? downloadProgress : null,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      downloadProgress > 0
                          ? '下载中 ${(downloadProgress * 100).toStringAsFixed(0)}%'
                          : '正在连接下载流...',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: downloadProgress > 0 ? downloadProgress : null,
                minHeight: 7,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: const Color(0xFFD8E3ED),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ] else
              FilledButton.tonalIcon(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  foregroundColor: accent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.download_rounded),
                label: const Text('下载'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF10273F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF54697A),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF34506A)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF34506A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({
    required this.label,
    required this.progress,
  });

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF10273F),
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress > 0 ? progress : null,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: const Color(0xFFD8E3ED),
            valueColor: const AlwaysStoppedAnimation(Color(0xFFE66A3B)),
          ),
          const SizedBox(height: 8),
          Text(
            progress > 0
                ? '${(progress * 100).toStringAsFixed(0)}%'
                : '正在建立下载连接...',
            style: const TextStyle(color: Color(0xFF54697A)),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.message,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foregroundColor,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '实现说明',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10273F),
            ),
          ),
          SizedBox(height: 8),
          Text(
            '这个版本复刻的是站点的核心能力，不是把网页嵌进去：输入链接、拿到视频元数据、展示下载项、保存到本地。',
            style: TextStyle(color: Color(0xFF54697A), height: 1.5),
          ),
          SizedBox(height: 8),
          Text(
            '当前已接入 YouTube、抖音，以及 iiilab / SnapAny 当前公开支持的 TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo、Threads 等平台。不同平台的直链都有时效，解析后建议尽快下载。',
            style: TextStyle(color: Color(0xFF54697A), height: 1.5),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
