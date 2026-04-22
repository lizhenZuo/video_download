import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import 'l10n/app_locale_store.dart';
import 'l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);

    if (_urlController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = l10n.pasteVideoLinkFirst;
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
    final l10n = AppLocalizations.of(context);

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
            content: Text(l10n.savedToFile(receipt.fileName)),
            action: _supportsDirectOpen
                ? SnackBarAction(
                    label: l10n.open,
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
        _errorMessage = l10n.downloadFailed(error);
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
        SnackBar(content: Text(context.l10n.cannotOpenFile(result.message))),
      );
    }
  }

  Future<void> _saveLastDownloadToGallery() async {
    final receipt = _lastDownload;
    if (receipt == null || !receipt.canSaveToGallery || _isSavingToGallery) {
      return;
    }
    final l10n = AppLocalizations.of(context);

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
              Platform.isIOS ? l10n.savedToPhotosIos : l10n.savedToPhotos,
            ),
          ),
        );
    } on GalException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = l10n.saveToGalleryFailed(_mapGalleryError(error));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = l10n.saveToGalleryFailed(error);
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
      final l10n = AppLocalizations.of(context);
      await SharePlus.instance.share(
        ShareParams(
          title: receipt.fileName,
          subject: receipt.fileName,
          text: l10n.shareFile(receipt.fileName),
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
        _errorMessage = context.l10n.shareFailed(error);
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
    final l10n = AppLocalizations.of(context);
    return switch (error.type) {
      GalExceptionType.accessDenied => l10n.galleryPermissionDenied,
      GalExceptionType.notEnoughSpace => l10n.galleryNotEnoughSpace,
      GalExceptionType.notSupportedFormat => l10n.galleryUnsupportedFormat,
      GalExceptionType.unexpected => l10n.galleryUnknownError,
    };
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push<_SettingsPageResult>(
      MaterialPageRoute<_SettingsPageResult>(
        builder: (context) => const _SettingsPage(),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.cacheCleared) {
      setState(() {
        _lastDownload = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                    label: Text(
                      l10n.settingsCenter,
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
                        Text(
                          l10n.parseVideo,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF10273F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.parseVideoIntro,
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
                            hintText: l10n.videoLinkHint,
                            suffixIcon: IconButton(
                              tooltip: l10n.pasteClipboard,
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
                                label: Text(
                                  _isExtracting ? l10n.parsing : l10n.parseVideo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_isDownloading) ...[
                          const SizedBox(height: 16),
                          _DownloadProgress(
                            label: _downloadLabel ?? l10n.download,
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
                                  child: Text(l10n.open),
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
                                    _isSavingToGallery
                                        ? l10n.saving
                                        : l10n.saveToGallery,
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
                                    label: Text(
                                      _isSharing ? l10n.sharing : l10n.share,
                                    ),
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
    final l10n = context.l10n;
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
              _heroChip(l10n.heroPlatforms),
              _heroChip(isExtracting || isDownloading
                  ? l10n.heroInProgress
                  : l10n.heroReady),
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
          Text(
            l10n.heroDescription,
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
    final l10n = context.l10n;
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
            _SectionTitle(
              title: l10n.quickDownload,
              subtitle: l10n.quickDownloadSubtitle,
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
              _SectionTitle(
                title: l10n.playableVideos,
                subtitle: l10n.playableVideosSubtitle,
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
              _SectionTitle(
                title: l10n.audioStreams,
                subtitle: l10n.audioStreamsSubtitle,
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
              _SectionTitle(
                title: l10n.highResVideos,
                subtitle: l10n.highResVideosSubtitle,
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
              _SectionTitle(
                title: l10n.imageDownloads,
                subtitle: l10n.imageDownloadsSubtitle,
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
  bool _localeChanged = false;

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
        final l10n = context.l10n;
        return AlertDialog(
          title: Text(l10n.clearCache),
          content: Text(
            cacheBytes > 0
                ? l10n.cacheDialogContent(_formatStorageSize(cacheBytes))
                : l10n.emptyCacheDialogContent,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(cacheBytes > 0 ? l10n.clear : l10n.refresh),
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
                  ? context.l10n.cacheCleared(_formatStorageSize(clearedBytes))
                  : context.l10n.noCache,
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
          SnackBar(content: Text(context.l10n.clearCacheFailed(error))),
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

  Future<void> _openLanguageSettings() async {
    if (!mounted) {
      return;
    }

    final currentLocale = AppLocalizations.of(context).locale;
    final languageChanged = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => _LanguageSelectionPage(
          initialLocale: currentLocale,
        ),
      ),
    );

    if (!mounted || languageChanged != true) {
      return;
    }

    _localeChanged = true;
    Navigator.of(context).pop(
      _SettingsPageResult(
        cacheCleared: _cacheCleared,
        localeChanged: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cacheLabel = _isLoadingCacheSize
        ? l10n.calculating
        : _formatStorageSize(_cacheBytes ?? 0);
    final currentLocale = AppLocalizations.of(context).locale;
    final currentLanguageLabel = l10n.languageDisplayName(currentLocale);

    return PopScope<_SettingsPageResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        Navigator.of(context).pop(
          _SettingsPageResult(
            cacheCleared: _cacheCleared,
            localeChanged: _localeChanged,
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settingsCenter),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(
              _SettingsPageResult(
                cacheCleared: _cacheCleared,
                localeChanged: _localeChanged,
              ),
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: ListTile(
                onTap: _openLanguageSettings,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  l10n.language,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10273F),
                  ),
                ),
                subtitle: Text(
                  l10n.languageSettingHint,
                  style: const TextStyle(height: 1.45),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        currentLanguageLabel,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE66A3B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                onTap: (_isLoadingCacheSize || _isClearingCache)
                    ? null
                    : _clearCache,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  l10n.cacheSize,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10273F),
                  ),
                ),
                subtitle: Text(
                  _isClearingCache
                      ? l10n.clearingCache
                      : l10n.clearCacheHint,
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
            Text(
              l10n.cacheFootnote,
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

class _SettingsPageResult {
  const _SettingsPageResult({
    required this.cacheCleared,
    required this.localeChanged,
  });

  final bool cacheCleared;
  final bool localeChanged;
}

class _LanguageSelectionPage extends StatefulWidget {
  const _LanguageSelectionPage({
    required this.initialLocale,
  });

  final Locale initialLocale;

  @override
  State<_LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<_LanguageSelectionPage> {
  late Locale _selectedLocale = AppLocalizations.resolve(widget.initialLocale);
  bool _isSaving = false;

  Future<void> _confirmSelection() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    await AppLocaleController.instance.updateLocale(_selectedLocale);
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(true);
  }

  bool _sameLocale(Locale left, Locale right) {
    return left.languageCode == right.languageCode &&
        left.scriptCode == right.scriptCode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final options = AppLocalizations.supportedLocales;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectLanguage),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                children: [
                  Text(
                    l10n.selectLanguageHint,
                    style: const TextStyle(
                      color: Color(0xFF54697A),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Column(
                      children: [
                        for (var index = 0; index < options.length; index++) ...[
                          RadioListTile<Locale>(
                            value: options[index],
                            groupValue: _selectedLocale,
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedLocale = value;
                              });
                            },
                            title: Text(l10n.languageDisplayName(options[index])),
                            activeColor: const Color(0xFFE66A3B),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 2,
                            ),
                          ),
                          if (index != options.length - 1)
                            const Divider(height: 1, indent: 18, endIndent: 18),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ||
                          _sameLocale(
                            AppLocalizations.resolve(widget.initialLocale),
                            _selectedLocale,
                          )
                      ? null
                      : _confirmSelection,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE66A3B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.confirm),
                ),
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
    final l10n = context.l10n;
    return Container(
      color: const Color(0xFFE6EDF3),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF5D7284),
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.coverLoadFailed,
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
    final l10n = context.l10n;
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
                    child: Text(
                      l10n.noAudioTrack,
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
                          ? l10n.downloadingPercent(downloadProgress)
                          : l10n.connectingDownloadStream,
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
                label: Text(l10n.download),
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
    final l10n = context.l10n;
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
                ? l10n.downloadConnectionProgress(progress)
                : l10n.connectingDownload,
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
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.footerTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF10273F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.footerDescription1,
            style: TextStyle(color: Color(0xFF54697A), height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.footerDescription2,
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
