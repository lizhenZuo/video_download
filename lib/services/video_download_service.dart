import '../models/download_models.dart';
import '../l10n/app_localizations.dart';
import 'bilibili_download_service.dart';
import 'direct_download_service.dart';
import 'douyin_download_service.dart';
import 'download_support.dart';
import 'iiilab_download_service.dart';
import 'snapany_download_service.dart';
import 'youtube_download_service.dart';

class VideoDownloadService {
  VideoDownloadService()
      : _youtube = YoutubeDownloadService(),
        _douyin = DouyinDownloadService(),
        _bilibili = BilibiliDownloadService(),
        _snapany = SnapAnyDownloadService(),
        _iiilab = IiilabDownloadService(),
        _direct = DirectDownloadService();

  final YoutubeDownloadService _youtube;
  final DouyinDownloadService _douyin;
  final BilibiliDownloadService _bilibili;
  final SnapAnyDownloadService _snapany;
  final IiilabDownloadService _iiilab;
  final DirectDownloadService _direct;

  Future<VideoExtractionResult> extract(String rawInput) async {
    final l10n = AppLocalizations.current;
    final normalizedInput = _extractFirstUrl(rawInput);

    if (normalizedInput == null) {
      throw VideoDownloadException(l10n.invalidVideoUrl);
    }

    return switch (_detectSource(normalizedInput)) {
      VideoSource.youtube => _youtube.extract(normalizedInput),
      VideoSource.douyin => _douyin.extract(normalizedInput),
      VideoSource.bilibili => _bilibili.extract(normalizedInput),
      VideoSource.snapany => _snapany.extract(normalizedInput),
      VideoSource.iiilab => _iiilab.extract(normalizedInput),
    };
  }

  Future<DownloadReceipt> downloadAsset(
    DownloadAsset asset, {
    required String videoTitle,
    ProgressReporter? onProgress,
  }) {
    if (asset.source == VideoSource.youtube && asset.streamInfo != null) {
      return _youtube.downloadAsset(
        asset,
        videoTitle: videoTitle,
        onProgress: onProgress,
      );
    }

    return _direct.downloadAsset(
      asset,
      videoTitle: videoTitle,
      onProgress: onProgress,
    );
  }

  void dispose() {
    _youtube.dispose();
    _douyin.dispose();
    _bilibili.dispose();
    _snapany.dispose();
    _iiilab.dispose();
    _direct.dispose();
  }

  String? _extractFirstUrl(String rawInput) {
    final input = rawInput.trim();
    if (input.isEmpty) {
      return null;
    }

    final match = RegExp(r'https?://[^\s]+').firstMatch(input);
    final candidate = match?.group(0) ?? input;
    final cleaned = candidate.replaceFirst(RegExp(r'[)\]\}>]+$'), '').trim();
    final uri = Uri.tryParse(cleaned);

    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return null;
    }

    return uri.toString();
  }

  VideoSource _detectSource(String input) {
    final uri = Uri.parse(input);
    final host = uri.host.toLowerCase();

    if (host.contains('youtube.com') || host == 'youtu.be') {
      return VideoSource.youtube;
    }

    if (host.contains('douyin.com') || host.contains('iesdouyin.com')) {
      return VideoSource.douyin;
    }

    if (host.contains('bilibili.com') || host == 'b23.tv') {
      return VideoSource.bilibili;
    }

    if (_snapany.canHandle(uri)) {
      return VideoSource.snapany;
    }

    if (_iiilab.canHandle(uri)) {
      return VideoSource.iiilab;
    }

    throw VideoDownloadException(
      AppLocalizations.current.unsupportedPlatformsMessage,
    );
  }
}
