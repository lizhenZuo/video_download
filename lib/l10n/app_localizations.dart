import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum _AppLanguage {
  en,
  zhHans,
  zhHant,
  vi,
  hi,
  th,
}

enum MetricKind {
  views,
  likes,
  shares,
}

class AppLocalizations {
  AppLocalizations._(this.locale, this._language);

  final Locale locale;
  final _AppLanguage _language;

  static AppLocalizations _current = AppLocalizations._(
    const Locale('en'),
    _AppLanguage.en,
  );

  static AppLocalizations get current => _current;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    Locale('vi'),
    Locale('hi'),
    Locale('th'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        _current;
  }

  static Locale resolve(Locale? locale) {
    if (locale == null) {
      return const Locale('en');
    }

    final languageCode = locale.languageCode.toLowerCase();
    if (languageCode == 'zh') {
      final scriptCode = locale.scriptCode?.toLowerCase();
      final countryCode = locale.countryCode?.toUpperCase();
      if (scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO') {
        return const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        );
      }
      return const Locale('zh');
    }

    if (languageCode == 'vi') {
      return const Locale('vi');
    }

    if (languageCode == 'hi') {
      return const Locale('hi');
    }

    if (languageCode == 'th') {
      return const Locale('th');
    }

    return const Locale('en');
  }

  static Locale resolveFromList(List<Locale>? locales) {
    if (locales == null || locales.isEmpty) {
      return const Locale('en');
    }

    for (final locale in locales) {
      final resolved = resolve(locale);
      if (supportedLocales.any(_sameLocale(resolved))) {
        return resolved;
      }
    }

    return const Locale('en');
  }

  static String localeStorageKey(Locale locale) {
    final resolved = resolve(locale);
    return switch (resolved.languageCode) {
      'zh' when resolved.scriptCode?.toLowerCase() == 'hant' => 'zh-Hant',
      'zh' => 'zh',
      'vi' => 'vi',
      'hi' => 'hi',
      'th' => 'th',
      _ => 'en',
    };
  }

  static Locale? localeFromStorageKey(String? value) {
    return switch (value) {
      'zh-Hant' => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
      'zh' => const Locale('zh'),
      'vi' => const Locale('vi'),
      'hi' => const Locale('hi'),
      'th' => const Locale('th'),
      'en' => const Locale('en'),
      _ => null,
    };
  }

  static bool Function(Locale locale) _sameLocale(Locale target) {
    return (locale) =>
        locale.languageCode == target.languageCode &&
        locale.scriptCode == target.scriptCode;
  }

  static AppLocalizations lookup(Locale locale) {
    final resolvedLocale = resolve(locale);
    final localizations = AppLocalizations._(
      resolvedLocale,
      _languageFor(resolvedLocale),
    );
    _current = localizations;
    return localizations;
  }

  static _AppLanguage _languageFor(Locale locale) {
    final languageCode = locale.languageCode.toLowerCase();
    if (languageCode == 'zh') {
      return locale.scriptCode?.toLowerCase() == 'hant'
          ? _AppLanguage.zhHant
          : _AppLanguage.zhHans;
    }
    if (languageCode == 'vi') {
      return _AppLanguage.vi;
    }
    if (languageCode == 'hi') {
      return _AppLanguage.hi;
    }
    if (languageCode == 'th') {
      return _AppLanguage.th;
    }
    return _AppLanguage.en;
  }

  String _text(String key) => _localizedValues[_language]![key]!;

  String _format(String key, Map<String, String> values) {
    var result = _text(key);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  String get appName => 'Tube Fetch';
  String get settingsCenter => _text('settingsCenter');
  String get language => _text('language');
  String get languageSettingHint => _text('languageSettingHint');
  String get selectLanguage => _text('selectLanguage');
  String get selectLanguageHint => _text('selectLanguageHint');
  String get displayMode => _text('displayMode');
  String get displayModeSettingHint => _text('displayModeSettingHint');
  String get selectDisplayMode => _text('selectDisplayMode');
  String get selectDisplayModeHint => _text('selectDisplayModeHint');
  String get followPhoneMode => _text('followPhoneMode');
  String get lightMode => _text('lightMode');
  String get darkMode => _text('darkMode');
  String get confirm => _text('confirm');
  String get parseVideo => _text('parseVideo');
  String get parsing => _text('parsing');
  String get parseVideoIntro => _text('parseVideoIntro');
  String get videoLinkHint => _text('videoLinkHint');
  String get pasteClipboard => _text('pasteClipboard');
  String get pasteVideoLinkFirst => _text('pasteVideoLinkFirst');
  String get open => _text('open');
  String get saveToGallery => _text('saveToGallery');
  String get saving => _text('saving');
  String get share => _text('share');
  String get sharing => _text('sharing');
  String get quickDownload => _text('quickDownload');
  String get quickDownloadSubtitle => _text('quickDownloadSubtitle');
  String get playableVideos => _text('playableVideos');
  String get playableVideosSubtitle => _text('playableVideosSubtitle');
  String get audioStreams => _text('audioStreams');
  String get audioStreamsSubtitle => _text('audioStreamsSubtitle');
  String get highResVideos => _text('highResVideos');
  String get highResVideosSubtitle => _text('highResVideosSubtitle');
  String get imageDownloads => _text('imageDownloads');
  String get imageDownloadsSubtitle => _text('imageDownloadsSubtitle');
  String get clearCache => _text('clearCache');
  String get cancel => _text('cancel');
  String get clear => _text('clear');
  String get refresh => _text('refresh');
  String get noCache => _text('noCache');
  String get cacheSize => _text('cacheSize');
  String get calculating => _text('calculating');
  String get clearingCache => _text('clearingCache');
  String get clearCacheHint => _text('clearCacheHint');
  String get cacheFootnote => _text('cacheFootnote');
  String get coverLoadFailed => _text('coverLoadFailed');
  String get noAudioTrack => _text('noAudioTrack');
  String get download => _text('download');
  String get connectingDownload => _text('connectingDownload');
  String get footerTitle => _text('footerTitle');
  String get footerDescription1 => _text('footerDescription1');
  String get footerDescription2 => _text('footerDescription2');
  String get heroPlatforms => _text('heroPlatforms');
  String get heroInProgress => _text('heroInProgress');
  String get heroReady => _text('heroReady');
  String get heroDescription => _text('heroDescription');
  String get galleryPermissionDenied => _text('galleryPermissionDenied');
  String get galleryNotEnoughSpace => _text('galleryNotEnoughSpace');
  String get galleryUnsupportedFormat => _text('galleryUnsupportedFormat');
  String get galleryUnknownError => _text('galleryUnknownError');
  String get invalidVideoUrl => _text('invalidVideoUrl');
  String get noAvailableDownloadUrl => _text('noAvailableDownloadUrl');
  String get outputDirectoryUnavailable => _text('outputDirectoryUnavailable');
  String get unknownBitrate => _text('unknownBitrate');
  String get defaultDownloadItem => _text('defaultDownloadItem');
  String get directLink => _text('directLink');
  String get directLinkDownload => _text('directLinkDownload');
  String get withAudioTrack => _text('withAudioTrack');
  String get videoOnly => _text('videoOnly');
  String get separatedAudioTrack => _text('separatedAudioTrack');
  String get previewImage => _text('previewImage');
  String get originalImage => _text('originalImage');
  String get pageCover => _text('pageCover');
  String get pageFirstFrame => _text('pageFirstFrame');
  String get sharePageCover => _text('sharePageCover');
  String get noWatermark => _text('noWatermark');
  String get withWatermark => _text('withWatermark');
  String get defaultCover => _text('defaultCover');
  String get unavailableMessage => _text('unavailableMessage');
  String get liveStreamNotSupported => _text('liveStreamNotSupported');
  String get highResWarning => _text('highResWarning');
  String get parseServiceExtraLimit => _text('parseServiceExtraLimit');
  String get parseServiceNoResult => _text('parseServiceNoResult');
  String get parseServiceNoMedia => _text('parseServiceNoMedia');
  String get snapAnyNoResult => _text('snapAnyNoResult');
  String get snapAnyNoMedia => _text('snapAnyNoMedia');
  String get ageRestricted => _text('ageRestricted');
  String get privateVideo => _text('privateVideo');
  String get membersOnlyVideo => _text('membersOnlyVideo');
  String get regionRestricted => _text('regionRestricted');
  String get signInRequired => _text('signInRequired');
  String get unsupportedPlatformsMessage =>
      _text('unsupportedPlatformsMessage');
  String get iiilabUnsupportedLink => _text('iiilabUnsupportedLink');
  String get snapAnyUnsupportedLink => _text('snapAnyUnsupportedLink');
  String get douyinStructureChanged => _text('douyinStructureChanged');
  String get bilibiliStructureChanged => _text('bilibiliStructureChanged');
  String get parseServiceFormatChanged => _text('parseServiceFormatChanged');
  String get snapAnyFormatChanged => _text('snapAnyFormatChanged');
  String get douyinNoRouterData => _text('douyinNoRouterData');
  String get douyinRouteDataInvalid => _text('douyinRouteDataInvalid');
  String get douyinLoaderDataMissing => _text('douyinLoaderDataMissing');
  String get douyinNoVideoInfo => _text('douyinNoVideoInfo');
  String get douyinNoShareData => _text('douyinNoShareData');
  String get bilibiliShortLinkInvalid => _text('bilibiliShortLinkInvalid');
  String get bilibiliNoPageContent => _text('bilibiliNoPageContent');
  String get bilibiliNoVideoInfo => _text('bilibiliNoVideoInfo');
  String get bilibiliNoDownloadAddress => _text('bilibiliNoDownloadAddress');
  String get bilibiliNoCover => _text('bilibiliNoCover');
  String get bilibiliNoVideoStream => _text('bilibiliNoVideoStream');
  String get douyinNoPageContent => _text('douyinNoPageContent');
  String get douyinNoDownloadAddress => _text('douyinNoDownloadAddress');

  String savedToFile(String fileName) =>
      _format('savedToFile', {'fileName': fileName});

  String downloadFailed(Object error) =>
      _format('downloadFailed', {'error': '$error'});

  String cannotOpenFile(String reason) =>
      _format('cannotOpenFile', {'reason': reason});

  String get savedToPhotosIos => _text('savedToPhotosIos');

  String get savedToPhotos => _text('savedToPhotos');

  String saveToGalleryFailed(Object error) =>
      _format('saveToGalleryFailed', {'error': '$error'});

  String shareFile(String fileName) =>
      _format('shareFile', {'fileName': fileName});

  String shareFailed(Object error) =>
      _format('shareFailed', {'error': '$error'});

  String cacheDialogContent(String cacheSize) =>
      _format('cacheDialogContent', {'cacheSize': cacheSize});

  String get emptyCacheDialogContent => _text('emptyCacheDialogContent');

  String cacheCleared(String cacheSize) =>
      _format('cacheCleared', {'cacheSize': cacheSize});

  String clearCacheFailed(Object error) =>
      _format('clearCacheFailed', {'error': '$error'});

  String downloadingPercent(double progress) => _format(
        'downloadingPercent',
        {'progress': (progress * 100).toStringAsFixed(0)},
      );

  String get connectingDownloadStream => _text('connectingDownloadStream');

  String downloadConnectionProgress(double progress) => _format(
        'downloadConnectionProgress',
        {'progress': (progress * 100).toStringAsFixed(0)},
      );

  String platformName(String key) {
    return switch (key) {
      'youtube' => 'YouTube',
      'douyin' => _text('platformDouyin'),
      'bilibili' => _text('platformBilibili'),
      'iiilab' => 'iiilab',
      'snapany' => 'SnapAny',
      'weibo' => _text('platformWeiboGroup'),
      'twitter' => 'Twitter / X',
      'instagram' => 'Instagram',
      'facebook' => 'Facebook',
      'zuiyou' => _text('platformZuiyou'),
      'weishi' => _text('platformWeishi'),
      'kg' => _text('platformKg'),
      'quanmin' => _text('platformQuanmin'),
      'momo' => _text('platformMomo'),
      'meipai' => _text('platformMeipai'),
      'vimeo' => 'Vimeo',
      'tumblr' => 'Tumblr',
      'yinyue' => _text('platformMusic163'),
      'quduopai' => _text('platformQutoutiao'),
      'inke' => _text('platformInke'),
      'xiaoying' => _text('platformXiaoying'),
      'pearvideo' => _text('platformPearVideo'),
      'tiktok' => 'TikTok',
      'pinterest' => 'Pinterest',
      'vk' => 'VK',
      'ok-ru' => 'OK.ru',
      'dailymotion' => 'Dailymotion',
      'reddit' => 'Reddit',
      'suno' => 'Suno',
      'threads' => 'Threads',
      _ => key,
    };
  }

  String invalidPlatformUrl(String platform) =>
      _format('invalidPlatformUrl', {'platform': platform});

  String noPageContent(String platform) =>
      _format('noPageContent', {'platform': platform});

  String noVideoInfo(String platform) =>
      _format('noVideoInfo', {'platform': platform});

  String noDownloadAddress(String platform) =>
      _format('noDownloadAddress', {'platform': platform});

  String noCoverForPlatform(String platform) =>
      _format('noCoverForPlatform', {'platform': platform});

  String noVideoStreamForPlatform(String platform) =>
      _format('noVideoStreamForPlatform', {'platform': platform});

  String parseFailed(String platform, Object error) =>
      _format('parseFailed', {'platform': platform, 'error': '$error'});

  String timeoutMessage(String platform, String detail) =>
      _format('timeoutMessage', {'platform': platform, 'detail': detail});

  String networkUnavailable(String platform, String detail) => _format(
        'networkUnavailable',
        {'platform': platform, 'detail': detail},
      );

  String handshakeFailed(String platform, String detail) =>
      _format('handshakeFailed', {'platform': platform, 'detail': detail});

  String requestRejected(String platform, String detail) =>
      _format('requestRejected', {'platform': platform, 'detail': detail});

  String requestFailed(String platform, String message) =>
      _format('requestFailed', {'platform': platform, 'message': message});

  String metricLabel(int value, MetricKind kind) {
    final suffix = switch (kind) {
      MetricKind.views => _text('metricViews'),
      MetricKind.likes => _text('metricLikes'),
      MetricKind.shares => _text('metricShares'),
    };

    return _compactCount(value, suffix);
  }

  String downloadItemsCount(int value) {
    return switch (_language) {
      _AppLanguage.zhHans => '$value 个下载项',
      _AppLanguage.zhHant => '$value 個下載項',
      _AppLanguage.vi => '$value mục tải xuống',
      _AppLanguage.hi => '$value डाउनलोड आइटम',
      _AppLanguage.th => '$value รายการดาวน์โหลด',
      _AppLanguage.en => '$value downloads',
    };
  }

  String videoQualityTitle(String quality) =>
      _format('videoQualityTitle', {'quality': quality});

  String audioBitrateTitle(String bitrate) =>
      _format('audioBitrateTitle', {'bitrate': bitrate});

  String highResVideoTitle(String quality) =>
      _format('highResVideoTitle', {'quality': quality});

  String watermarkedVideoTitle(String quality) =>
      _format('watermarkedVideoTitle', {'quality': quality});

  String videoTitleWithIndex(int index) =>
      _format('videoTitleWithIndex', {'index': '$index'});

  String imageTitle(int index) {
    if (index <= 1) {
      return _text('imageTitle');
    }
    return _format('imageTitleWithIndex', {'index': '$index'});
  }

  String get audioTitle => _text('audioTitle');
  String get videoTitle => _text('videoTitle');
  String get directVideoTitle => _text('directVideoTitle');
  String get thumbnailTitle => _text('thumbnailTitle');
  String get coverTitle => _text('coverTitle');
  String get firstFrameTitle => _text('firstFrameTitle');
  String get originalQuality => _text('originalQuality');

  String contentTitle(String platform) =>
      _format('contentTitle', {'platform': platform});

  String parseResultTitle(String platform) =>
      _format('parseResultTitle', {'platform': platform});

  String defaultAuthor(String platform) =>
      _format('defaultAuthor', {'platform': platform});

  String bilibiliWarning(String platform) =>
      _format('bilibiliWarning', {'platform': platform});

  String douyinWarning(String platform) =>
      _format('douyinWarning', {'platform': platform});

  String iiilabWarning(String platform) =>
      _format('iiilabWarning', {'platform': platform});

  String snapAnyWarning(String platform) =>
      _format('snapAnyWarning', {'platform': platform});

  String overseasNetworkWarning(String platform) =>
      _format('overseasNetworkWarning', {'platform': platform});

  String get muxingWarning => _text('muxingWarning');

  String get youtubeTimeoutDetail => _text('youtubeTimeoutDetail');
  String get youtubeNetworkDetail => _text('youtubeNetworkDetail');
  String get youtubeHandshakeDetail => _text('youtubeHandshakeDetail');
  String get douyinTimeoutDetail => _text('douyinTimeoutDetail');
  String get douyinNetworkDetail => _text('douyinNetworkDetail');
  String get douyinHandshakeDetail => _text('douyinHandshakeDetail');
  String get bilibiliTimeoutDetail => _text('bilibiliTimeoutDetail');
  String get bilibiliNetworkDetail => _text('bilibiliNetworkDetail');
  String get bilibiliHandshakeDetail => _text('bilibiliHandshakeDetail');
  String get parserTimeoutDetail => _text('parserTimeoutDetail');
  String get parserNetworkDetail => _text('parserNetworkDetail');
  String get parserHandshakeDetail => _text('parserHandshakeDetail');
  String get retryLaterDetail => _text('retryLaterDetail');
  String get snapAnyRetryLaterDetail => _text('snapAnyRetryLaterDetail');
  String get snapAnyRateLimited => _text('snapAnyRateLimited');

  String languageDisplayName(Locale locale) {
    final resolved = resolve(locale);
    return switch (localeStorageKey(resolved)) {
      'zh' => '简体中文',
      'zh-Hant' => '繁體中文',
      'vi' => 'Tiếng Việt',
      'hi' => 'हिन्दी',
      'th' => 'ไทย',
      _ => 'English',
    };
  }

  String themeModeDisplayName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => followPhoneMode,
      ThemeMode.light => lightMode,
      ThemeMode.dark => darkMode,
    };
  }

  String _compactCount(int value, String suffix) {
    return switch (_language) {
      _AppLanguage.zhHans => _compactZh(value, suffix, '亿', '万'),
      _AppLanguage.zhHant => _compactZh(value, suffix, '億', '萬'),
      _AppLanguage.vi => _compactAbbreviated(value, suffix),
      _AppLanguage.hi => _compactAbbreviated(value, suffix),
      _AppLanguage.th => _compactAbbreviated(value, suffix),
      _AppLanguage.en => _compactAbbreviated(value, suffix),
    };
  }

  String _compactZh(int value, String suffix, String yi, String wan) {
    if (value >= 100000000) {
      return '${(value / 100000000).toStringAsFixed(1)}$yi$suffix';
    }
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}$wan$suffix';
    }
    return '$value $suffix';
  }

  String _compactAbbreviated(int value, String suffix) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B $suffix';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M $suffix';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K $suffix';
    }
    return '$value $suffix';
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final resolved = AppLocalizations.resolve(locale);
    return AppLocalizations.supportedLocales.any(
      (supported) =>
          supported.languageCode == resolved.languageCode &&
          supported.scriptCode == resolved.scriptCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations.lookup(locale),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _localizedValues = <_AppLanguage, Map<String, String>>{
  _AppLanguage.en: {
    'settingsCenter': 'Settings',
    'language': 'Language',
    'languageSettingHint':
        'Open the language picker and switch the app display language.',
    'selectLanguage': 'Select Language',
    'selectLanguageHint':
        'Choose a language, then confirm to apply it immediately.',
    'displayMode': 'Display Mode',
    'displayModeSettingHint':
        'Switch between follow-phone, light, and dark appearance modes.',
    'selectDisplayMode': 'Choose Display Mode',
    'selectDisplayModeHint':
        'Choose a mode and confirm to apply it immediately.',
    'followPhoneMode': 'Follow Phone',
    'lightMode': 'Light Mode',
    'darkMode': 'Dark Mode',
    'confirm': 'Confirm',
    'parseVideo': 'Parse Video',
    'parsing': 'Parsing...',
    'parseVideoIntro':
        'Handle YouTube, Douyin, and the links currently exposed by iiilab / SnapAny, including TikTok, Bilibili, Twitter, Instagram, Facebook, Vimeo, Threads, and more.',
    'videoLinkHint':
        'Paste a video link, for example YouTube, Douyin, TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo...',
    'pasteClipboard': 'Paste from clipboard',
    'pasteVideoLinkFirst': 'Paste a video link first.',
    'savedToFile': 'Saved to {fileName}',
    'open': 'Open',
    'downloadFailed': 'Download failed: {error}',
    'cannotOpenFile': 'Unable to open the file directly: {reason}',
    'savedToPhotosIos': 'Saved to Photos. Open the Photos app to view it.',
    'savedToPhotos': 'Saved to Photos',
    'saveToGalleryFailed': 'Save to gallery failed: {error}',
    'shareFile': 'Share file: {fileName}',
    'shareFailed': 'Share failed: {error}',
    'galleryPermissionDenied':
        'Photo access is denied. Allow photo access in system settings.',
    'galleryNotEnoughSpace': 'Not enough free storage on this device.',
    'galleryUnsupportedFormat':
        'This file format cannot be saved to the system gallery.',
    'galleryUnknownError': 'The system gallery returned an unknown error.',
    'heroPlatforms': 'YouTube + Douyin + Multi-platform',
    'heroInProgress': 'In Progress',
    'heroReady': 'Ready to Run',
    'heroDescription':
        'Paste a link to parse cover images and downloadable video, audio, image, or share-page direct links, then save locally, to the gallery, or share through the system sheet.',
    'quickDownload': 'Quick Downloads',
    'quickDownloadSubtitle':
        'The most common items appear here and change with platform capabilities.',
    'playableVideos': 'Directly Playable Video Streams',
    'playableVideosSubtitle':
        'Includes audio. You can open it directly after downloading.',
    'audioStreams': 'Audio-only Streams',
    'audioStreamsSubtitle':
        'Useful when you only want the sound or plan to merge it later.',
    'highResVideos': 'High-resolution Video Streams',
    'highResVideosSubtitle':
        'Often 1080p / 4K, but usually without audio tracks.',
    'imageDownloads': 'Images / Cover Downloads',
    'imageDownloadsSubtitle':
        'Original gallery images and cover images are grouped here.',
    'clearCache': 'Clear Cache',
    'cacheDialogContent':
        'Current cache is about {cacheSize}. After clearing, files downloaded inside the app but not saved elsewhere will be deleted.',
    'emptyCacheDialogContent':
        'There is no cache to clear right now. Refresh the cache status anyway?',
    'cancel': 'Cancel',
    'clear': 'Clear',
    'refresh': 'Refresh',
    'cacheCleared': 'Cleared {cacheSize} of cache',
    'noCache': 'There is no cache to clear right now',
    'clearCacheFailed': 'Failed to clear cache: {error}',
    'calculating': 'Calculating...',
    'cacheSize': 'Cache Size',
    'clearingCache': 'Clearing app cache...',
    'clearCacheHint':
        'Tap to clear cached files from the app download directory.',
    'cacheFootnote':
        'This clears files in the app-managed download directory only. Copies already saved to Photos or shared through the system are not affected.',
    'coverLoadFailed': 'Cover failed to load',
    'noAudioTrack': 'No Audio',
    'downloadingPercent': 'Downloading {progress}%',
    'connectingDownloadStream': 'Connecting to download stream...',
    'download': 'Download',
    'connectingDownload': 'Establishing download connection...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': 'Implementation Notes',
    'footerDescription1':
        'This build recreates the core capability instead of embedding the website: enter a link, fetch metadata, show downloadable items, and save locally.',
    'footerDescription2':
        'It currently includes YouTube, Douyin, and the platforms currently exposed by iiilab / SnapAny, such as TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo, and Threads. Direct links are time-limited, so download soon after parsing.',
    'invalidVideoUrl': 'Please enter a valid video link.',
    'unsupportedPlatformsMessage':
        'Only YouTube, Douyin, Bilibili, and the platforms currently exposed by iiilab / SnapAny are supported right now, including TikTok, Twitter, Instagram, Facebook, Vimeo, and Threads.',
    'noAvailableDownloadUrl':
        'The selected item does not contain a valid file URL.',
    'outputDirectoryUnavailable':
        'Unable to locate an available download directory.',
    'unknownBitrate': 'Unknown bitrate',
    'defaultDownloadItem': 'Default download item',
    'directLink': 'Direct link',
    'directLinkDownload': 'Direct link download',
    'withAudioTrack': 'With audio',
    'videoOnly': 'Video only',
    'separatedAudioTrack': 'Separated audio track',
    'previewImage': 'Preview image',
    'originalImage': 'Original image',
    'pageCover': 'Page cover',
    'pageFirstFrame': 'First frame',
    'sharePageCover': 'Share page cover',
    'noWatermark': 'No watermark',
    'withWatermark': 'With watermark',
    'defaultCover': 'Default cover',
    'unavailableMessage':
        'This video is unavailable, or the current network cannot fetch a YouTube media stream directly.',
    'liveStreamNotSupported':
        'Live streams are not supported for offline download yet.',
    'highResWarning':
        'Streams above 1080p are usually video-only. Merge them with audio if you want a directly playable file.',
    'parseServiceExtraLimit':
        'The parser service is currently under extra restrictions. Please try again later.',
    'parseServiceNoResult':
        'The parser service did not return a usable result.',
    'parseServiceNoMedia': 'No downloadable media was found for this content.',
    'snapAnyNoResult': 'SnapAny did not return a usable result.',
    'snapAnyNoMedia': 'No downloadable media was found in SnapAny.',
    'ageRestricted':
        'This video is age-restricted, and the current parsing method cannot access its streams.',
    'privateVideo': 'This video is private and cannot be downloaded.',
    'membersOnlyVideo':
        'This video is members-only and cannot be downloaded right now.',
    'regionRestricted':
        'This video is region-restricted for the current network location.',
    'signInRequired':
        'This video requires a signed-in session, which is not available here.',
    'iiilabUnsupportedLink':
        'This link is not in the platform list currently supported by iiilab.',
    'snapAnyUnsupportedLink':
        'This link is not in the platform list currently supported by SnapAny.',
    'douyinStructureChanged':
        'The Douyin page structure has changed and cannot be parsed for now.',
    'bilibiliStructureChanged':
        'The Bilibili page structure has changed and cannot be parsed for now.',
    'parseServiceFormatChanged':
        'The parser service returned an unexpected payload and cannot be handled for now.',
    'snapAnyFormatChanged':
        'SnapAny returned an unexpected payload and cannot be handled for now.',
    'douyinNoRouterData':
        'No parseable route data was found on the Douyin page.',
    'douyinRouteDataInvalid': 'The Douyin route payload is invalid.',
    'douyinLoaderDataMissing': 'The Douyin page is missing loaderData.',
    'douyinNoVideoInfo': 'No video information was found on the Douyin page.',
    'douyinNoShareData':
        'The current Douyin video does not expose usable share-page data.',
    'douyinNoPageContent': 'The Douyin page returned no parseable content.',
    'douyinNoDownloadAddress':
        'The current Douyin video does not expose usable download URLs.',
    'bilibiliShortLinkInvalid':
        'The short link did not resolve to a usable Bilibili video URL.',
    'bilibiliNoPageContent': 'The Bilibili page returned no parseable content.',
    'bilibiliNoVideoInfo':
        'No usable video information was found on the Bilibili page.',
    'bilibiliNoDownloadAddress':
        'The current Bilibili video does not expose usable download URLs.',
    'bilibiliNoCover':
        'The current Bilibili video does not expose a usable cover image.',
    'bilibiliNoVideoStream':
        'The current Bilibili video does not expose a usable video stream.',
    'platformDouyin': 'Douyin',
    'platformBilibili': 'Bilibili',
    'platformWeiboGroup': 'Weibo / Miaopai / Oasis',
    'platformZuiyou': 'Zuiyou',
    'platformWeishi': 'Weishi',
    'platformKg': 'K Song',
    'platformQuanmin': 'Quanmin Short Video',
    'platformMomo': 'Momo',
    'platformMeipai': 'Meipai',
    'platformMusic163': 'NetEase Music',
    'platformQutoutiao': 'Qutoutiao',
    'platformInke': 'Inke',
    'platformXiaoying': 'Xiaoying / VivaVideo',
    'platformPearVideo': 'Pear Video',
    'invalidPlatformUrl': 'Please enter a valid {platform} link.',
    'noPageContent': 'The {platform} page returned no parseable content.',
    'noVideoInfo':
        'No usable video information was found for the current {platform} content.',
    'noDownloadAddress':
        'The current {platform} content does not expose usable download URLs.',
    'noCoverForPlatform':
        'The current {platform} content does not expose a usable cover image.',
    'noVideoStreamForPlatform':
        'The current {platform} content does not expose a usable video stream.',
    'parseFailed': 'Failed to parse {platform}: {error}',
    'timeoutMessage': 'Timed out while connecting to {platform}. {detail}',
    'networkUnavailable': 'This device cannot reach {platform}. {detail}',
    'handshakeFailed':
        'Failed to establish a secure connection with {platform}. {detail}',
    'requestRejected': '{platform} rejected this request for now. {detail}',
    'requestFailed': '{platform} request failed: {message}',
    'metricViews': 'views',
    'metricLikes': 'likes',
    'metricShares': 'shares',
    'videoQualityTitle': 'Video {quality}',
    'audioBitrateTitle': 'Audio {bitrate}',
    'highResVideoTitle': 'High-res {quality}',
    'watermarkedVideoTitle': 'Video {quality} (watermark)',
    'videoTitleWithIndex': 'Video {index}',
    'imageTitle': 'Image',
    'imageTitleWithIndex': 'Image {index}',
    'audioTitle': 'Audio',
    'videoTitle': 'Video',
    'directVideoTitle': 'Direct video',
    'thumbnailTitle': 'Thumbnail',
    'coverTitle': 'Cover image',
    'firstFrameTitle': 'First frame',
    'originalQuality': 'Original quality',
    'contentTitle': '{platform} content',
    'parseResultTitle': '{platform} parse result',
    'defaultAuthor': '{platform} author',
    'bilibiliWarning':
        'This result is parsed directly from the {platform} mobile page. Video and cover links expire, so download soon after parsing.',
    'douyinWarning':
        'This result is parsed from the {platform} share page and only exposes direct MP4 video plus cover images. Separate audio and more qualities are not available yet.',
    'iiilabWarning':
        'This result comes from the iiilab parser and returns direct links that usually expire. Download soon after parsing.',
    'snapAnyWarning':
        'This result comes from the SnapAny parser and returns direct links that usually expire. Download soon after parsing.',
    'overseasNetworkWarning':
        'Downloading {platform} content still depends on the current network environment.',
    'muxingWarning':
        'Some high-resolution videos do not include audio. Merge them with an audio track if you want direct playback.',
    'youtubeTimeoutDetail':
        'The current network usually cannot reach YouTube reliably.',
    'youtubeNetworkDetail':
        'Confirm that the current network can access YouTube, then try again.',
    'youtubeHandshakeDetail':
        'Check the current network or proxy configuration.',
    'douyinTimeoutDetail':
        'The current network usually cannot reach the Douyin share page reliably.',
    'douyinNetworkDetail':
        'Confirm that the current network can access Douyin, then try again.',
    'douyinHandshakeDetail':
        'Check the current network or proxy configuration.',
    'bilibiliTimeoutDetail': 'Please try again later.',
    'bilibiliNetworkDetail': 'Check the network connection and try again.',
    'bilibiliHandshakeDetail': 'Check the current network environment.',
    'parserTimeoutDetail': 'Please try again later.',
    'parserNetworkDetail': 'Check the network connection and try again.',
    'parserHandshakeDetail': 'Check the current network environment.',
    'retryLaterDetail': 'Try again later for a more stable result.',
    'snapAnyRetryLaterDetail':
        'Wait a moment before retrying for a more stable result.',
    'snapAnyRateLimited':
        'SnapAny is currently rate limiting requests. Please try again later.',
  },
  _AppLanguage.zhHans: {
    'settingsCenter': '设置中心',
    'language': '语言',
    'languageSettingHint': '进入语言选择页并切换 App 显示语言。',
    'selectLanguage': '选择语言',
    'selectLanguageHint': '选中新的语言后点击确认，会立即应用并返回首页。',
    'displayMode': '显示模式',
    'displayModeSettingHint': '切换跟随手机、普通模式或暗黑模式。',
    'selectDisplayMode': '选择显示模式',
    'selectDisplayModeHint': '选中新的模式后点击确认，会立即应用并返回首页。',
    'followPhoneMode': '跟随手机',
    'lightMode': '普通模式',
    'darkMode': '暗黑模式',
    'confirm': '确认',
    'parseVideo': '解析视频',
    'parsing': '解析中...',
    'parseVideoIntro':
        '统一处理 YouTube、抖音，以及 iiilab / SnapAny 当前公开支持的 TikTok、Bilibili、Twitter、Instagram、Facebook、Vimeo、Threads 等平台链接。',
    'videoLinkHint':
        '粘贴视频链接，例如 YouTube、抖音、TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo...',
    'pasteClipboard': '粘贴剪贴板',
    'pasteVideoLinkFirst': '先粘贴一个视频链接。',
    'savedToFile': '已保存到 {fileName}',
    'open': '打开',
    'downloadFailed': '下载失败：{error}',
    'cannotOpenFile': '无法直接打开文件：{reason}',
    'savedToPhotosIos': '已保存到系统相册，请到“照片”App 查看',
    'savedToPhotos': '已保存到系统相册',
    'saveToGalleryFailed': '保存到相册失败：{error}',
    'shareFile': '分享文件：{fileName}',
    'shareFailed': '分享失败：{error}',
    'galleryPermissionDenied': '没有相册权限，请在系统设置里允许访问照片。',
    'galleryNotEnoughSpace': '设备剩余空间不足。',
    'galleryUnsupportedFormat': '当前文件格式不支持保存到系统相册。',
    'galleryUnknownError': '系统相册返回了未知错误。',
    'heroPlatforms': 'YouTube + 抖音 + 多平台',
    'heroInProgress': '进行中',
    'heroReady': '可直接运行',
    'heroDescription': '把链接粘进来，解析封面和可下载的视频、音频、图片或分享页直链，支持保存到本地、相册和系统分享。',
    'quickDownload': '快速下载',
    'quickDownloadSubtitle': '最常用的下载项，会根据平台能力自动变化。',
    'playableVideos': '可直接播放的视频流',
    'playableVideosSubtitle': '带音轨，下载后可直接打开。',
    'audioStreams': '独立音频流',
    'audioStreamsSubtitle': '适合只保留声音或后续单独合并。',
    'highResVideos': '高分辨率视频流',
    'highResVideosSubtitle': '常见为 1080p / 4K，但不带音轨。',
    'imageDownloads': '图片 / 封面下载',
    'imageDownloadsSubtitle': '图集原图、封面图会统一放在这里。',
    'clearCache': '清空缓存',
    'cacheDialogContent': '当前缓存约 {cacheSize}。清空后，App 内已下载但未另存到系统相册的位置文件会被删除。',
    'emptyCacheDialogContent': '当前没有可清理的缓存。仍然继续刷新缓存状态吗？',
    'cancel': '取消',
    'clear': '清空',
    'refresh': '刷新',
    'cacheCleared': '已清空 {cacheSize} 缓存',
    'noCache': '当前没有可清理的缓存',
    'clearCacheFailed': '清空缓存失败：{error}',
    'calculating': '正在计算...',
    'cacheSize': '缓存大小',
    'clearingCache': '正在清空 App 缓存...',
    'clearCacheHint': '点击后可清空 App 内下载目录中的缓存文件。',
    'cacheFootnote': '这里清理的是 App 管理目录里的下载文件，不会影响你已经保存到系统相册或通过系统分享出去的副本。',
    'coverLoadFailed': '封面加载失败',
    'noAudioTrack': '无音轨',
    'downloadingPercent': '下载中 {progress}%',
    'connectingDownloadStream': '正在连接下载流...',
    'download': '下载',
    'connectingDownload': '正在建立下载连接...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': '实现说明',
    'footerDescription1': '这个版本复刻的是站点的核心能力，不是把网页嵌进去：输入链接、拿到视频元数据、展示下载项、保存到本地。',
    'footerDescription2':
        '当前已接入 YouTube、抖音，以及 iiilab / SnapAny 当前公开支持的 TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo、Threads 等平台。不同平台的直链都有时效，解析后建议尽快下载。',
    'invalidVideoUrl': '请输入有效的视频链接。',
    'unsupportedPlatformsMessage':
        '当前只支持 YouTube、抖音、哔哩哔哩，以及 iiilab / SnapAny 当前公开支持的 TikTok、Twitter、Instagram、Facebook、Vimeo、Threads 等平台链接。',
    'noAvailableDownloadUrl': '下载项缺少可用的文件地址。',
    'outputDirectoryUnavailable': '无法定位可用的下载目录。',
    'unknownBitrate': '未知码率',
    'defaultDownloadItem': '默认下载项',
    'directLink': '直链',
    'directLinkDownload': '直链下载',
    'withAudioTrack': '带音轨',
    'videoOnly': '仅视频',
    'separatedAudioTrack': '分离音轨',
    'previewImage': '预览图',
    'originalImage': '原图直链',
    'pageCover': '页面封面',
    'pageFirstFrame': '页面首帧',
    'sharePageCover': '分享页封面',
    'noWatermark': '无水印',
    'withWatermark': '带水印',
    'defaultCover': '默认封面',
    'unavailableMessage': '当前视频不可播放，或者当前网络环境无法直接拿到 YouTube 媒体流。',
    'liveStreamNotSupported': '直播流暂不支持离线下载。',
    'highResWarning': '1080p 以上通常是无音轨视频流，下载后若想直接播放，需要再与音频合并。',
    'parseServiceExtraLimit': '解析服务当前触发了额外限制，请稍后重试。',
    'parseServiceNoResult': '解析服务没有返回可用结果。',
    'parseServiceNoMedia': '当前内容没有可下载的媒体资源。',
    'snapAnyNoResult': 'SnapAny 没有返回可用结果。',
    'snapAnyNoMedia': '当前内容没有可下载的媒体资源。',
    'ageRestricted': '这个视频触发了年龄限制，当前解析方式拿不到可下载流。',
    'privateVideo': '这个视频是私有视频，无法解析下载。',
    'membersOnlyVideo': '这个视频是会员专属内容，当前无法解析下载。',
    'regionRestricted': '这个视频受地区限制，当前网络区域拿不到可下载流。',
    'signInRequired': '这个视频需要登录态才能访问，当前解析方式拿不到可下载流。',
    'iiilabUnsupportedLink': '当前链接不在 iiilab 已支持的平台列表内。',
    'snapAnyUnsupportedLink': '当前链接不在 SnapAny 已支持的平台列表内。',
    'douyinStructureChanged': '当前抖音页面结构已变化，暂时无法解析。',
    'bilibiliStructureChanged': '当前哔哩哔哩页面结构已变化，暂时无法解析。',
    'parseServiceFormatChanged': '解析服务返回的数据格式异常，暂时无法处理。',
    'snapAnyFormatChanged': 'SnapAny 返回的数据格式异常，暂时无法处理。',
    'douyinNoRouterData': '当前抖音页面没有可解析的路由数据。',
    'douyinRouteDataInvalid': '抖音路由数据格式异常。',
    'douyinLoaderDataMissing': '抖音页面缺少 loaderData。',
    'douyinNoVideoInfo': '当前抖音页面没有视频信息。',
    'douyinNoShareData': '当前抖音视频没有可用的分享页数据。',
    'douyinNoPageContent': '抖音页面没有返回可解析内容。',
    'douyinNoDownloadAddress': '当前抖音视频没有可用的下载地址。',
    'bilibiliShortLinkInvalid': '当前短链没有解析到可用的哔哩哔哩视频地址。',
    'bilibiliNoPageContent': '哔哩哔哩页面没有返回可解析内容。',
    'bilibiliNoVideoInfo': '当前哔哩哔哩页面没有可用的视频信息。',
    'bilibiliNoDownloadAddress': '当前哔哩哔哩视频没有可用的下载地址。',
    'bilibiliNoCover': '当前哔哩哔哩视频没有可用封面。',
    'bilibiliNoVideoStream': '当前哔哩哔哩视频没有可用的视频流。',
    'platformDouyin': '抖音',
    'platformBilibili': '哔哩哔哩',
    'platformWeiboGroup': '微博 / 秒拍 / 绿洲',
    'platformZuiyou': '最右',
    'platformWeishi': '微视',
    'platformKg': '全民K歌',
    'platformQuanmin': '全民小视频',
    'platformMomo': '陌陌',
    'platformMeipai': '美拍',
    'platformMusic163': '云音乐',
    'platformQutoutiao': '趣头条',
    'platformInke': '映客',
    'platformXiaoying': '小影 / VivaVideo',
    'platformPearVideo': '梨视频',
    'invalidPlatformUrl': '请输入有效的 {platform} 视频链接。',
    'noPageContent': '{platform} 页面没有返回可解析内容。',
    'noVideoInfo': '当前 {platform} 页面没有可用的视频信息。',
    'noDownloadAddress': '当前 {platform} 内容没有可用的下载地址。',
    'noCoverForPlatform': '当前 {platform} 内容没有可用封面。',
    'noVideoStreamForPlatform': '当前 {platform} 内容没有可用的视频流。',
    'parseFailed': '解析{platform}失败：{error}',
    'timeoutMessage': '连接{platform}超时。{detail}',
    'networkUnavailable': '当前设备无法连接到{platform}。{detail}',
    'handshakeFailed': '和{platform}建立安全连接失败。{detail}',
    'requestRejected': '{platform}暂时拒绝了这次解析请求。{detail}',
    'requestFailed': '{platform}请求失败：{message}',
    'metricViews': '播放',
    'metricLikes': '点赞',
    'metricShares': '分享',
    'videoQualityTitle': '视频 {quality}',
    'audioBitrateTitle': '音频 {bitrate}',
    'highResVideoTitle': '高分辨率 {quality}',
    'watermarkedVideoTitle': '视频 {quality}（水印）',
    'videoTitleWithIndex': '视频 {index}',
    'imageTitle': '图片',
    'imageTitleWithIndex': '图片 {index}',
    'audioTitle': '音频',
    'videoTitle': '视频',
    'directVideoTitle': '视频直链',
    'thumbnailTitle': '封面图',
    'coverTitle': '封面图',
    'firstFrameTitle': '首帧图',
    'originalQuality': '原始清晰度',
    'contentTitle': '{platform} 内容',
    'parseResultTitle': '{platform} 解析结果',
    'defaultAuthor': '{platform}作者',
    'bilibiliWarning': '当前通过{platform}移动页直接解析，视频和封面直链都有时效，解析后建议尽快下载。',
    'douyinWarning': '当前通过{platform}分享页解析，只提供直连 MP4 视频和封面图；独立音频与更多清晰度暂不提供。',
    'iiilabWarning': '当前通过 iiilab 通用解析接口返回直链，资源链接通常有时效，建议尽快下载。',
    'snapAnyWarning': '当前通过 SnapAny 在线解析接口返回直链，资源链接通常有时效，建议尽快下载。',
    'overseasNetworkWarning': '下载{platform}资源仍然依赖当前网络环境。',
    'muxingWarning': '部分高分辨率视频不带音轨，如需直接播放，需要再和音频合并。',
    'youtubeTimeoutDetail': '通常是当前网络无法稳定访问 YouTube。',
    'youtubeNetworkDetail': '请先确认网络环境可访问 YouTube，再重试。',
    'youtubeHandshakeDetail': '请检查当前网络或代理配置。',
    'douyinTimeoutDetail': '通常是当前网络无法稳定访问抖音分享页。',
    'douyinNetworkDetail': '请先确认网络环境可访问抖音，再重试。',
    'douyinHandshakeDetail': '请检查当前网络或代理配置。',
    'bilibiliTimeoutDetail': '请稍后重试。',
    'bilibiliNetworkDetail': '请检查网络后重试。',
    'bilibiliHandshakeDetail': '请检查当前网络环境。',
    'parserTimeoutDetail': '请稍后重试。',
    'parserNetworkDetail': '请检查网络后重试。',
    'parserHandshakeDetail': '请检查当前网络环境。',
    'retryLaterDetail': '稍后重试更稳。',
    'snapAnyRetryLaterDetail': '请稍等后再试，成功率更稳。',
    'snapAnyRateLimited': 'SnapAny 当前限制了请求频率，请稍后再试。',
  },
  _AppLanguage.zhHant: {
    'settingsCenter': '設定中心',
    'language': '語言',
    'languageSettingHint': '進入語言選擇頁並切換 App 顯示語言。',
    'selectLanguage': '選擇語言',
    'selectLanguageHint': '選取新的語言後點擊確認，會立即套用並返回首頁。',
    'displayMode': '顯示模式',
    'displayModeSettingHint': '切換跟隨手機、普通模式或暗黑模式。',
    'selectDisplayMode': '選擇顯示模式',
    'selectDisplayModeHint': '選取新的模式後點擊確認，會立即套用並返回首頁。',
    'followPhoneMode': '跟隨手機',
    'lightMode': '普通模式',
    'darkMode': '暗黑模式',
    'confirm': '確認',
    'parseVideo': '解析影片',
    'parsing': '解析中...',
    'parseVideoIntro':
        '統一處理 YouTube、抖音，以及 iiilab / SnapAny 目前公開支援的 TikTok、Bilibili、Twitter、Instagram、Facebook、Vimeo、Threads 等平台連結。',
    'videoLinkHint':
        '貼上影片連結，例如 YouTube、抖音、TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo...',
    'pasteClipboard': '貼上剪貼簿',
    'pasteVideoLinkFirst': '請先貼上一個影片連結。',
    'savedToFile': '已儲存到 {fileName}',
    'open': '打開',
    'downloadFailed': '下載失敗：{error}',
    'cannotOpenFile': '無法直接打開檔案：{reason}',
    'savedToPhotosIos': '已儲存到系統相簿，請到「照片」App 查看',
    'savedToPhotos': '已儲存到系統相簿',
    'saveToGalleryFailed': '儲存到相簿失敗：{error}',
    'shareFile': '分享檔案：{fileName}',
    'shareFailed': '分享失敗：{error}',
    'galleryPermissionDenied': '沒有相簿權限，請在系統設定中允許存取照片。',
    'galleryNotEnoughSpace': '裝置剩餘空間不足。',
    'galleryUnsupportedFormat': '目前檔案格式不支援儲存到系統相簿。',
    'galleryUnknownError': '系統相簿回傳了未知錯誤。',
    'heroPlatforms': 'YouTube + 抖音 + 多平台',
    'heroInProgress': '進行中',
    'heroReady': '可直接執行',
    'heroDescription': '把連結貼進來，解析封面與可下載的影片、音訊、圖片或分享頁直鏈，支援儲存到本機、相簿與系統分享。',
    'quickDownload': '快速下載',
    'quickDownloadSubtitle': '最常用的下載項會依平台能力自動變化。',
    'playableVideos': '可直接播放的影片串流',
    'playableVideosSubtitle': '含音軌，下載後可直接打開。',
    'audioStreams': '獨立音訊串流',
    'audioStreamsSubtitle': '適合只保留聲音或之後再單獨合併。',
    'highResVideos': '高解析度影片串流',
    'highResVideosSubtitle': '常見為 1080p / 4K，但不含音軌。',
    'imageDownloads': '圖片 / 封面下載',
    'imageDownloadsSubtitle': '圖集原圖與封面圖會統一放在這裡。',
    'clearCache': '清除快取',
    'cacheDialogContent': '目前快取約 {cacheSize}。清除後，App 內已下載但未另存到系統相簿的位置檔案會被刪除。',
    'emptyCacheDialogContent': '目前沒有可清理的快取。仍要繼續重新整理快取狀態嗎？',
    'cancel': '取消',
    'clear': '清除',
    'refresh': '重新整理',
    'cacheCleared': '已清除 {cacheSize} 快取',
    'noCache': '目前沒有可清理的快取',
    'clearCacheFailed': '清除快取失敗：{error}',
    'calculating': '計算中...',
    'cacheSize': '快取大小',
    'clearingCache': '正在清除 App 快取...',
    'clearCacheHint': '點擊後可清除 App 下載目錄中的快取檔案。',
    'cacheFootnote': '這裡清理的是 App 管理目錄中的下載檔案，不會影響你已經儲存到系統相簿或透過系統分享送出的副本。',
    'coverLoadFailed': '封面載入失敗',
    'noAudioTrack': '無音軌',
    'downloadingPercent': '下載中 {progress}%',
    'connectingDownloadStream': '正在連接下載串流...',
    'download': '下載',
    'connectingDownload': '正在建立下載連線...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': '實作說明',
    'footerDescription1':
        '這個版本復刻的是網站的核心能力，不是把網頁直接嵌入：輸入連結、拿到影片中繼資料、顯示下載項並儲存到本機。',
    'footerDescription2':
        '目前已接入 YouTube、抖音，以及 iiilab / SnapAny 目前公開支援的 TikTok、Bilibili、微博、Twitter、Instagram、Facebook、Vimeo、Threads 等平台。不同平台的直鏈都有時效，解析後建議儘快下載。',
    'invalidVideoUrl': '請輸入有效的影片連結。',
    'unsupportedPlatformsMessage':
        '目前只支援 YouTube、抖音、嗶哩嗶哩，以及 iiilab / SnapAny 目前公開支援的 TikTok、Twitter、Instagram、Facebook、Vimeo、Threads 等平台連結。',
    'noAvailableDownloadUrl': '下載項缺少可用的檔案位址。',
    'outputDirectoryUnavailable': '無法定位可用的下載目錄。',
    'unknownBitrate': '未知位元率',
    'defaultDownloadItem': '預設下載項',
    'directLink': '直鏈',
    'directLinkDownload': '直鏈下載',
    'withAudioTrack': '含音軌',
    'videoOnly': '僅影片',
    'separatedAudioTrack': '分離音軌',
    'previewImage': '預覽圖',
    'originalImage': '原圖直鏈',
    'pageCover': '頁面封面',
    'pageFirstFrame': '頁面首幀',
    'sharePageCover': '分享頁封面',
    'noWatermark': '無浮水印',
    'withWatermark': '有浮水印',
    'defaultCover': '預設封面',
    'unavailableMessage': '目前影片不可播放，或當前網路環境無法直接取得 YouTube 媒體串流。',
    'liveStreamNotSupported': '直播串流暫不支援離線下載。',
    'highResWarning': '1080p 以上通常是無音軌影片串流，下載後若想直接播放，需要再與音訊合併。',
    'parseServiceExtraLimit': '解析服務目前觸發了額外限制，請稍後重試。',
    'parseServiceNoResult': '解析服務沒有回傳可用結果。',
    'parseServiceNoMedia': '目前內容沒有可下載的媒體資源。',
    'snapAnyNoResult': 'SnapAny 沒有回傳可用結果。',
    'snapAnyNoMedia': '目前內容沒有可下載的媒體資源。',
    'ageRestricted': '這支影片觸發了年齡限制，目前解析方式拿不到可下載串流。',
    'privateVideo': '這支影片是私人影片，無法解析下載。',
    'membersOnlyVideo': '這支影片是會員專屬內容，目前無法解析下載。',
    'regionRestricted': '這支影片受地區限制，目前網路區域拿不到可下載串流。',
    'signInRequired': '這支影片需要登入狀態才能存取，目前解析方式拿不到可下載串流。',
    'iiilabUnsupportedLink': '目前連結不在 iiilab 已支援的平台清單內。',
    'snapAnyUnsupportedLink': '目前連結不在 SnapAny 已支援的平台清單內。',
    'douyinStructureChanged': '目前抖音頁面結構已變更，暫時無法解析。',
    'bilibiliStructureChanged': '目前嗶哩嗶哩頁面結構已變更，暫時無法解析。',
    'parseServiceFormatChanged': '解析服務回傳的資料格式異常，暫時無法處理。',
    'snapAnyFormatChanged': 'SnapAny 回傳的資料格式異常，暫時無法處理。',
    'douyinNoRouterData': '目前抖音頁面沒有可解析的路由資料。',
    'douyinRouteDataInvalid': '抖音路由資料格式異常。',
    'douyinLoaderDataMissing': '抖音頁面缺少 loaderData。',
    'douyinNoVideoInfo': '目前抖音頁面沒有影片資訊。',
    'douyinNoShareData': '目前抖音影片沒有可用的分享頁資料。',
    'douyinNoPageContent': '抖音頁面沒有回傳可解析內容。',
    'douyinNoDownloadAddress': '目前抖音影片沒有可用的下載位址。',
    'bilibiliShortLinkInvalid': '目前短連結沒有解析到可用的嗶哩嗶哩影片位址。',
    'bilibiliNoPageContent': '嗶哩嗶哩頁面沒有回傳可解析內容。',
    'bilibiliNoVideoInfo': '目前嗶哩嗶哩頁面沒有可用的影片資訊。',
    'bilibiliNoDownloadAddress': '目前嗶哩嗶哩影片沒有可用的下載位址。',
    'bilibiliNoCover': '目前嗶哩嗶哩影片沒有可用封面。',
    'bilibiliNoVideoStream': '目前嗶哩嗶哩影片沒有可用的影片串流。',
    'platformDouyin': '抖音',
    'platformBilibili': '嗶哩嗶哩',
    'platformWeiboGroup': '微博 / 秒拍 / 綠洲',
    'platformZuiyou': '最右',
    'platformWeishi': '微視',
    'platformKg': '全民K歌',
    'platformQuanmin': '全民小影片',
    'platformMomo': '陌陌',
    'platformMeipai': '美拍',
    'platformMusic163': '雲音樂',
    'platformQutoutiao': '趣頭條',
    'platformInke': '映客',
    'platformXiaoying': '小影 / VivaVideo',
    'platformPearVideo': '梨影片',
    'invalidPlatformUrl': '請輸入有效的 {platform} 影片連結。',
    'noPageContent': '{platform} 頁面沒有回傳可解析內容。',
    'noVideoInfo': '目前 {platform} 頁面沒有可用的影片資訊。',
    'noDownloadAddress': '目前 {platform} 內容沒有可用的下載位址。',
    'noCoverForPlatform': '目前 {platform} 內容沒有可用封面。',
    'noVideoStreamForPlatform': '目前 {platform} 內容沒有可用的影片串流。',
    'parseFailed': '解析{platform}失敗：{error}',
    'timeoutMessage': '連接{platform}逾時。{detail}',
    'networkUnavailable': '目前裝置無法連接到{platform}。{detail}',
    'handshakeFailed': '與{platform}建立安全連線失敗。{detail}',
    'requestRejected': '{platform}暫時拒絕了這次解析請求。{detail}',
    'requestFailed': '{platform}請求失敗：{message}',
    'metricViews': '播放',
    'metricLikes': '按讚',
    'metricShares': '分享',
    'videoQualityTitle': '影片 {quality}',
    'audioBitrateTitle': '音訊 {bitrate}',
    'highResVideoTitle': '高解析度 {quality}',
    'watermarkedVideoTitle': '影片 {quality}（浮水印）',
    'videoTitleWithIndex': '影片 {index}',
    'imageTitle': '圖片',
    'imageTitleWithIndex': '圖片 {index}',
    'audioTitle': '音訊',
    'videoTitle': '影片',
    'directVideoTitle': '影片直鏈',
    'thumbnailTitle': '封面圖',
    'coverTitle': '封面圖',
    'firstFrameTitle': '首幀圖',
    'originalQuality': '原始畫質',
    'contentTitle': '{platform} 內容',
    'parseResultTitle': '{platform} 解析結果',
    'defaultAuthor': '{platform}作者',
    'bilibiliWarning': '目前透過{platform}行動頁直接解析，影片與封面直鏈都有時效，解析後建議儘快下載。',
    'douyinWarning': '目前透過{platform}分享頁解析，只提供直連 MP4 影片與封面圖；獨立音訊與更多清晰度暫不提供。',
    'iiilabWarning': '目前透過 iiilab 通用解析介面回傳直鏈，資源連結通常有時效，建議儘快下載。',
    'snapAnyWarning': '目前透過 SnapAny 線上解析介面回傳直鏈，資源連結通常有時效，建議儘快下載。',
    'overseasNetworkWarning': '下載{platform}資源仍然依賴目前網路環境。',
    'muxingWarning': '部分高解析度影片不含音軌，如需直接播放，需要再與音訊合併。',
    'youtubeTimeoutDetail': '通常是目前網路無法穩定存取 YouTube。',
    'youtubeNetworkDetail': '請先確認網路環境可存取 YouTube，再重試。',
    'youtubeHandshakeDetail': '請檢查目前網路或代理設定。',
    'douyinTimeoutDetail': '通常是目前網路無法穩定存取抖音分享頁。',
    'douyinNetworkDetail': '請先確認網路環境可存取抖音，再重試。',
    'douyinHandshakeDetail': '請檢查目前網路或代理設定。',
    'bilibiliTimeoutDetail': '請稍後再試。',
    'bilibiliNetworkDetail': '請檢查網路後重試。',
    'bilibiliHandshakeDetail': '請檢查目前網路環境。',
    'parserTimeoutDetail': '請稍後再試。',
    'parserNetworkDetail': '請檢查網路後重試。',
    'parserHandshakeDetail': '請檢查目前網路環境。',
    'retryLaterDetail': '稍後重試會更穩定。',
    'snapAnyRetryLaterDetail': '請稍等後再試，成功率會更穩。',
    'snapAnyRateLimited': 'SnapAny 目前限制了請求頻率，請稍後再試。',
  },
  _AppLanguage.vi: {
    'settingsCenter': 'Cài đặt',
    'language': 'Ngôn ngữ',
    'languageSettingHint':
        'Mở trang chọn ngôn ngữ và đổi ngôn ngữ hiển thị của ứng dụng.',
    'selectLanguage': 'Chọn ngôn ngữ',
    'selectLanguageHint':
        'Chọn ngôn ngữ mới rồi nhấn xác nhận để áp dụng ngay.',
    'displayMode': 'Chế độ hiển thị',
    'displayModeSettingHint':
        'Chuyển giữa chế độ theo điện thoại, sáng hoặc tối.',
    'selectDisplayMode': 'Chọn chế độ hiển thị',
    'selectDisplayModeHint':
        'Chọn chế độ mới rồi nhấn xác nhận để áp dụng ngay.',
    'followPhoneMode': 'Theo điện thoại',
    'lightMode': 'Chế độ sáng',
    'darkMode': 'Chế độ tối',
    'confirm': 'Xác nhận',
    'parseVideo': 'Phân tích video',
    'parsing': 'Đang phân tích...',
    'parseVideoIntro':
        'Xử lý thống nhất các liên kết YouTube, Douyin và các nền tảng mà iiilab / SnapAny hiện đang công khai hỗ trợ như TikTok, Bilibili, Twitter, Instagram, Facebook, Vimeo, Threads...',
    'videoLinkHint':
        'Dán liên kết video, ví dụ: YouTube, Douyin, TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo...',
    'pasteClipboard': 'Dán từ bộ nhớ tạm',
    'pasteVideoLinkFirst': 'Hãy dán một liên kết video trước.',
    'savedToFile': 'Đã lưu vào {fileName}',
    'open': 'Mở',
    'downloadFailed': 'Tải xuống thất bại: {error}',
    'cannotOpenFile': 'Không thể mở trực tiếp tệp: {reason}',
    'savedToPhotosIos': 'Đã lưu vào Ảnh. Mở ứng dụng Ảnh để xem.',
    'savedToPhotos': 'Đã lưu vào thư viện ảnh',
    'saveToGalleryFailed': 'Lưu vào thư viện thất bại: {error}',
    'shareFile': 'Chia sẻ tệp: {fileName}',
    'shareFailed': 'Chia sẻ thất bại: {error}',
    'galleryPermissionDenied':
        'Không có quyền truy cập ảnh. Hãy cấp quyền trong cài đặt hệ thống.',
    'galleryNotEnoughSpace': 'Thiết bị không đủ dung lượng trống.',
    'galleryUnsupportedFormat':
        'Định dạng tệp này không thể lưu vào thư viện hệ thống.',
    'galleryUnknownError': 'Thư viện hệ thống trả về lỗi không xác định.',
    'heroPlatforms': 'YouTube + Douyin + Đa nền tảng',
    'heroInProgress': 'Đang xử lý',
    'heroReady': 'Sẵn sàng',
    'heroDescription':
        'Dán liên kết để phân tích ảnh bìa và các liên kết trực tiếp có thể tải xuống cho video, âm thanh, hình ảnh hoặc trang chia sẻ, rồi lưu cục bộ, vào thư viện hoặc chia sẻ qua hệ thống.',
    'quickDownload': 'Tải nhanh',
    'quickDownloadSubtitle':
        'Các mục phổ biến nhất sẽ xuất hiện ở đây và thay đổi theo khả năng của nền tảng.',
    'playableVideos': 'Luồng video phát trực tiếp',
    'playableVideosSubtitle': 'Có âm thanh. Có thể mở ngay sau khi tải.',
    'audioStreams': 'Luồng âm thanh riêng',
    'audioStreamsSubtitle': 'Phù hợp khi chỉ cần âm thanh hoặc muốn ghép sau.',
    'highResVideos': 'Luồng video độ phân giải cao',
    'highResVideosSubtitle': 'Thường là 1080p / 4K nhưng không có âm thanh.',
    'imageDownloads': 'Tải ảnh / ảnh bìa',
    'imageDownloadsSubtitle':
        'Ảnh gốc trong bộ sưu tập và ảnh bìa sẽ được gom ở đây.',
    'clearCache': 'Xóa bộ nhớ đệm',
    'cacheDialogContent':
        'Bộ nhớ đệm hiện tại khoảng {cacheSize}. Sau khi xóa, các tệp đã tải trong ứng dụng nhưng chưa lưu nơi khác sẽ bị xóa.',
    'emptyCacheDialogContent':
        'Hiện không có bộ nhớ đệm để xóa. Vẫn làm mới trạng thái bộ nhớ đệm?',
    'cancel': 'Hủy',
    'clear': 'Xóa',
    'refresh': 'Làm mới',
    'cacheCleared': 'Đã xóa {cacheSize} bộ nhớ đệm',
    'noCache': 'Hiện không có bộ nhớ đệm để xóa',
    'clearCacheFailed': 'Xóa bộ nhớ đệm thất bại: {error}',
    'calculating': 'Đang tính...',
    'cacheSize': 'Dung lượng bộ nhớ đệm',
    'clearingCache': 'Đang xóa bộ nhớ đệm của ứng dụng...',
    'clearCacheHint':
        'Chạm để xóa các tệp đệm trong thư mục tải xuống của ứng dụng.',
    'cacheFootnote':
        'Thao tác này chỉ xóa tệp trong thư mục tải xuống do ứng dụng quản lý. Bản sao đã lưu vào Ảnh hoặc đã chia sẻ qua hệ thống sẽ không bị ảnh hưởng.',
    'coverLoadFailed': 'Tải ảnh bìa thất bại',
    'noAudioTrack': 'Không có âm thanh',
    'downloadingPercent': 'Đang tải {progress}%',
    'connectingDownloadStream': 'Đang kết nối luồng tải xuống...',
    'download': 'Tải xuống',
    'connectingDownload': 'Đang thiết lập kết nối tải xuống...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': 'Ghi chú triển khai',
    'footerDescription1':
        'Phiên bản này tái tạo năng lực cốt lõi của trang web thay vì nhúng thẳng trang: nhập liên kết, lấy metadata, hiển thị mục tải xuống và lưu cục bộ.',
    'footerDescription2':
        'Hiện đã hỗ trợ YouTube, Douyin và các nền tảng đang được iiilab / SnapAny công khai hỗ trợ như TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo và Threads. Liên kết trực tiếp có thời hạn, nên hãy tải sớm sau khi phân tích.',
    'invalidVideoUrl': 'Vui lòng nhập liên kết video hợp lệ.',
    'unsupportedPlatformsMessage':
        'Hiện chỉ hỗ trợ YouTube, Douyin, Bilibili và các nền tảng đang được iiilab / SnapAny công khai hỗ trợ như TikTok, Twitter, Instagram, Facebook, Vimeo và Threads.',
    'noAvailableDownloadUrl': 'Mục tải xuống này không có địa chỉ tệp hợp lệ.',
    'outputDirectoryUnavailable':
        'Không thể xác định thư mục tải xuống khả dụng.',
    'unknownBitrate': 'Bitrate không xác định',
    'defaultDownloadItem': 'Mục tải xuống mặc định',
    'directLink': 'Liên kết trực tiếp',
    'directLinkDownload': 'Tải trực tiếp',
    'withAudioTrack': 'Có âm thanh',
    'videoOnly': 'Chỉ video',
    'separatedAudioTrack': 'Âm thanh tách rời',
    'previewImage': 'Ảnh xem trước',
    'originalImage': 'Ảnh gốc',
    'pageCover': 'Ảnh bìa trang',
    'pageFirstFrame': 'Khung hình đầu',
    'sharePageCover': 'Ảnh bìa trang chia sẻ',
    'noWatermark': 'Không watermark',
    'withWatermark': 'Có watermark',
    'defaultCover': 'Ảnh bìa mặc định',
    'unavailableMessage':
        'Video hiện không thể phát hoặc mạng hiện tại không thể lấy trực tiếp luồng media YouTube.',
    'liveStreamNotSupported':
        'Luồng trực tiếp hiện chưa hỗ trợ tải ngoại tuyến.',
    'highResWarning':
        'Các luồng trên 1080p thường chỉ có video. Hãy ghép với âm thanh nếu muốn phát trực tiếp.',
    'parseServiceExtraLimit':
        'Dịch vụ phân tích hiện đang bị hạn chế thêm. Vui lòng thử lại sau.',
    'parseServiceNoResult': 'Dịch vụ phân tích không trả về kết quả khả dụng.',
    'parseServiceNoMedia':
        'Không tìm thấy tài nguyên media có thể tải xuống cho nội dung này.',
    'snapAnyNoResult': 'SnapAny không trả về kết quả khả dụng.',
    'snapAnyNoMedia':
        'Không tìm thấy tài nguyên media có thể tải xuống trong SnapAny.',
    'ageRestricted':
        'Video này bị giới hạn độ tuổi và phương thức phân tích hiện tại không lấy được luồng tải xuống.',
    'privateVideo': 'Video này ở chế độ riêng tư và không thể tải xuống.',
    'membersOnlyVideo':
        'Video này chỉ dành cho thành viên và hiện không thể tải xuống.',
    'regionRestricted': 'Video này bị giới hạn khu vực đối với mạng hiện tại.',
    'signInRequired':
        'Video này yêu cầu trạng thái đăng nhập và hiện không thể truy cập.',
    'iiilabUnsupportedLink':
        'Liên kết này không nằm trong danh sách nền tảng mà iiilab hiện hỗ trợ.',
    'snapAnyUnsupportedLink':
        'Liên kết này không nằm trong danh sách nền tảng mà SnapAny hiện hỗ trợ.',
    'douyinStructureChanged':
        'Cấu trúc trang Douyin đã thay đổi và hiện không thể phân tích.',
    'bilibiliStructureChanged':
        'Cấu trúc trang Bilibili đã thay đổi và hiện không thể phân tích.',
    'parseServiceFormatChanged':
        'Dịch vụ phân tích trả về định dạng dữ liệu bất thường và hiện chưa thể xử lý.',
    'snapAnyFormatChanged':
        'SnapAny trả về định dạng dữ liệu bất thường và hiện chưa thể xử lý.',
    'douyinNoRouterData':
        'Không tìm thấy dữ liệu route có thể phân tích trên trang Douyin.',
    'douyinRouteDataInvalid': 'Dữ liệu route của Douyin không hợp lệ.',
    'douyinLoaderDataMissing': 'Trang Douyin thiếu loaderData.',
    'douyinNoVideoInfo': 'Không tìm thấy thông tin video trên trang Douyin.',
    'douyinNoShareData':
        'Video Douyin hiện tại không có dữ liệu trang chia sẻ khả dụng.',
    'douyinNoPageContent':
        'Trang Douyin không trả về nội dung có thể phân tích.',
    'douyinNoDownloadAddress':
        'Video Douyin hiện tại không có địa chỉ tải xuống khả dụng.',
    'bilibiliShortLinkInvalid':
        'Liên kết rút gọn không phân giải được sang video Bilibili khả dụng.',
    'bilibiliNoPageContent':
        'Trang Bilibili không trả về nội dung có thể phân tích.',
    'bilibiliNoVideoInfo':
        'Không tìm thấy thông tin video khả dụng trên trang Bilibili.',
    'bilibiliNoDownloadAddress':
        'Video Bilibili hiện tại không có địa chỉ tải xuống khả dụng.',
    'bilibiliNoCover': 'Video Bilibili hiện tại không có ảnh bìa khả dụng.',
    'bilibiliNoVideoStream':
        'Video Bilibili hiện tại không có luồng video khả dụng.',
    'platformDouyin': 'Douyin',
    'platformBilibili': 'Bilibili',
    'platformWeiboGroup': 'Weibo / Miaopai / Oasis',
    'platformZuiyou': 'Zuiyou',
    'platformWeishi': 'Weishi',
    'platformKg': '全民K歌',
    'platformQuanmin': 'Video ngắn Quanmin',
    'platformMomo': 'Momo',
    'platformMeipai': 'Meipai',
    'platformMusic163': 'NetEase Music',
    'platformQutoutiao': 'Qutoutiao',
    'platformInke': 'Inke',
    'platformXiaoying': 'Xiaoying / VivaVideo',
    'platformPearVideo': 'Pear Video',
    'invalidPlatformUrl': 'Vui lòng nhập liên kết {platform} hợp lệ.',
    'noPageContent': 'Trang {platform} không trả về nội dung có thể phân tích.',
    'noVideoInfo':
        'Không tìm thấy thông tin video khả dụng cho nội dung {platform} hiện tại.',
    'noDownloadAddress':
        'Nội dung {platform} hiện tại không có địa chỉ tải xuống khả dụng.',
    'noCoverForPlatform':
        'Nội dung {platform} hiện tại không có ảnh bìa khả dụng.',
    'noVideoStreamForPlatform':
        'Nội dung {platform} hiện tại không có luồng video khả dụng.',
    'parseFailed': 'Phân tích {platform} thất bại: {error}',
    'timeoutMessage': 'Hết thời gian kết nối tới {platform}. {detail}',
    'networkUnavailable':
        'Thiết bị này không thể kết nối tới {platform}. {detail}',
    'handshakeFailed':
        'Không thể thiết lập kết nối bảo mật với {platform}. {detail}',
    'requestRejected': '{platform} tạm thời từ chối yêu cầu này. {detail}',
    'requestFailed': 'Yêu cầu tới {platform} thất bại: {message}',
    'metricViews': 'lượt xem',
    'metricLikes': 'lượt thích',
    'metricShares': 'lượt chia sẻ',
    'videoQualityTitle': 'Video {quality}',
    'audioBitrateTitle': 'Âm thanh {bitrate}',
    'highResVideoTitle': 'Độ phân giải cao {quality}',
    'watermarkedVideoTitle': 'Video {quality} (watermark)',
    'videoTitleWithIndex': 'Video {index}',
    'imageTitle': 'Ảnh',
    'imageTitleWithIndex': 'Ảnh {index}',
    'audioTitle': 'Âm thanh',
    'videoTitle': 'Video',
    'directVideoTitle': 'Video trực tiếp',
    'thumbnailTitle': 'Ảnh thu nhỏ',
    'coverTitle': 'Ảnh bìa',
    'firstFrameTitle': 'Khung hình đầu',
    'originalQuality': 'Chất lượng gốc',
    'contentTitle': 'Nội dung {platform}',
    'parseResultTitle': 'Kết quả phân tích {platform}',
    'defaultAuthor': 'Tác giả {platform}',
    'bilibiliWarning':
        'Kết quả này được phân tích trực tiếp từ trang di động {platform}. Liên kết video và ảnh bìa đều có thời hạn, hãy tải xuống sớm sau khi phân tích.',
    'douyinWarning':
        'Kết quả này được phân tích từ trang chia sẻ {platform} và chỉ cung cấp video MP4 trực tiếp cùng ảnh bìa. Âm thanh riêng và các mức chất lượng khác hiện chưa có.',
    'iiilabWarning':
        'Kết quả này đến từ bộ phân tích iiilab và trả về liên kết trực tiếp thường có thời hạn. Hãy tải xuống sớm sau khi phân tích.',
    'snapAnyWarning':
        'Kết quả này đến từ bộ phân tích SnapAny và trả về liên kết trực tiếp thường có thời hạn. Hãy tải xuống sớm sau khi phân tích.',
    'overseasNetworkWarning':
        'Việc tải nội dung {platform} vẫn phụ thuộc vào môi trường mạng hiện tại.',
    'muxingWarning':
        'Một số video độ phân giải cao không có âm thanh. Hãy ghép thêm track âm thanh nếu muốn phát trực tiếp.',
    'youtubeTimeoutDetail':
        'Mạng hiện tại thường không truy cập YouTube ổn định.',
    'youtubeNetworkDetail':
        'Hãy xác nhận mạng hiện tại có thể truy cập YouTube rồi thử lại.',
    'youtubeHandshakeDetail': 'Hãy kiểm tra cấu hình mạng hoặc proxy hiện tại.',
    'douyinTimeoutDetail':
        'Mạng hiện tại thường không truy cập ổn định trang chia sẻ Douyin.',
    'douyinNetworkDetail':
        'Hãy xác nhận mạng hiện tại có thể truy cập Douyin rồi thử lại.',
    'douyinHandshakeDetail': 'Hãy kiểm tra cấu hình mạng hoặc proxy hiện tại.',
    'bilibiliTimeoutDetail': 'Vui lòng thử lại sau.',
    'bilibiliNetworkDetail': 'Kiểm tra kết nối mạng rồi thử lại.',
    'bilibiliHandshakeDetail': 'Kiểm tra môi trường mạng hiện tại.',
    'parserTimeoutDetail': 'Vui lòng thử lại sau.',
    'parserNetworkDetail': 'Kiểm tra kết nối mạng rồi thử lại.',
    'parserHandshakeDetail': 'Kiểm tra môi trường mạng hiện tại.',
    'retryLaterDetail': 'Thử lại sau sẽ ổn định hơn.',
    'snapAnyRetryLaterDetail': 'Hãy đợi một lát rồi thử lại để ổn định hơn.',
    'snapAnyRateLimited':
        'SnapAny hiện đang giới hạn tần suất yêu cầu. Vui lòng thử lại sau.',
  },
  _AppLanguage.hi: {
    'settingsCenter': 'सेटिंग्स',
    'language': 'भाषा',
    'languageSettingHint': 'भाषा चयन पेज खोलें और ऐप की डिस्प्ले भाषा बदलें।',
    'selectLanguage': 'भाषा चुनें',
    'selectLanguageHint':
        'नई भाषा चुनकर पुष्टि दबाएं, भाषा तुरंत लागू हो जाएगी।',
    'displayMode': 'डिस्प्ले मोड',
    'displayModeSettingHint':
        'फोन के अनुसार, लाइट मोड या डार्क मोड के बीच बदलें।',
    'selectDisplayMode': 'डिस्प्ले मोड चुनें',
    'selectDisplayModeHint':
        'नया मोड चुनकर पुष्टि करें, यह तुरंत लागू हो जाएगा।',
    'followPhoneMode': 'फोन के अनुसार',
    'lightMode': 'लाइट मोड',
    'darkMode': 'डार्क मोड',
    'confirm': 'पुष्टि करें',
    'parseVideo': 'वीडियो पार्स करें',
    'parsing': 'पार्स किया जा रहा है...',
    'parseVideoIntro':
        'YouTube, Douyin और iiilab / SnapAny द्वारा अभी सार्वजनिक रूप से समर्थित TikTok, Bilibili, Twitter, Instagram, Facebook, Vimeo, Threads आदि लिंक को एक ही जगह से संभालें।',
    'videoLinkHint':
        'वीडियो लिंक पेस्ट करें, जैसे YouTube, Douyin, TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo...',
    'pasteClipboard': 'क्लिपबोर्ड से पेस्ट करें',
    'pasteVideoLinkFirst': 'पहले एक वीडियो लिंक पेस्ट करें।',
    'savedToFile': '{fileName} में सहेजा गया',
    'open': 'खोलें',
    'downloadFailed': 'डाउनलोड विफल: {error}',
    'cannotOpenFile': 'फाइल सीधे नहीं खोली जा सकती: {reason}',
    'savedToPhotosIos': 'फ़ोटो में सहेजा गया। देखने के लिए Photos ऐप खोलें।',
    'savedToPhotos': 'गैलरी में सहेजा गया',
    'saveToGalleryFailed': 'गैलरी में सहेजना विफल: {error}',
    'shareFile': 'फ़ाइल साझा करें: {fileName}',
    'shareFailed': 'शेयर विफल: {error}',
    'galleryPermissionDenied':
        'फ़ोटो की अनुमति नहीं है। सिस्टम सेटिंग्स में अनुमति दें।',
    'galleryNotEnoughSpace': 'डिवाइस में पर्याप्त खाली स्थान नहीं है।',
    'galleryUnsupportedFormat':
        'यह फ़ाइल फ़ॉर्मेट सिस्टम गैलरी में सहेजा नहीं जा सकता।',
    'galleryUnknownError': 'सिस्टम गैलरी ने अज्ञात त्रुटि लौटाई।',
    'heroPlatforms': 'YouTube + Douyin + मल्टी-प्लेटफ़ॉर्म',
    'heroInProgress': 'प्रक्रिया में',
    'heroReady': 'तैयार',
    'heroDescription':
        'लिंक पेस्ट करें, कवर और डाउनलोड योग्य वीडियो, ऑडियो, इमेज या शेयर-पेज डायरेक्ट लिंक पार्स करें, फिर लोकल, गैलरी या सिस्टम शेयर से सहेजें।',
    'quickDownload': 'त्वरित डाउनलोड',
    'quickDownloadSubtitle':
        'सबसे आम आइटम यहां दिखेंगे और प्लेटफ़ॉर्म क्षमता के अनुसार बदलेंगे।',
    'playableVideos': 'सीधे चलने योग्य वीडियो स्ट्रीम',
    'playableVideosSubtitle': 'ऑडियो सहित। डाउनलोड के बाद सीधे खोल सकते हैं।',
    'audioStreams': 'अलग ऑडियो स्ट्रीम',
    'audioStreamsSubtitle':
        'सिर्फ आवाज़ चाहिए या बाद में मर्ज करना हो तो उपयोगी।',
    'highResVideos': 'हाई-रेज़ोल्यूशन वीडियो स्ट्रीम',
    'highResVideosSubtitle':
        'अक्सर 1080p / 4K होते हैं, लेकिन आमतौर पर बिना ऑडियो के।',
    'imageDownloads': 'इमेज / कवर डाउनलोड',
    'imageDownloadsSubtitle': 'मूल इमेज और कवर इमेज यहां एक साथ दिखाई जाएंगी।',
    'clearCache': 'कैश साफ़ करें',
    'cacheDialogContent':
        'मौजूदा कैश लगभग {cacheSize} है। साफ़ करने के बाद, ऐप के अंदर डाउनलोड की गई लेकिन कहीं और सहेजी न गई फाइलें हट जाएंगी।',
    'emptyCacheDialogContent':
        'अभी साफ़ करने के लिए कोई कैश नहीं है। फिर भी कैश स्थिति रीफ़्रेश करें?',
    'cancel': 'रद्द करें',
    'clear': 'साफ़ करें',
    'refresh': 'रीफ़्रेश',
    'cacheCleared': '{cacheSize} कैश साफ़ किया गया',
    'noCache': 'अभी साफ़ करने के लिए कोई कैश नहीं है',
    'clearCacheFailed': 'कैश साफ़ करना विफल: {error}',
    'calculating': 'गणना की जा रही है...',
    'cacheSize': 'कैश आकार',
    'clearingCache': 'ऐप कैश साफ़ किया जा रहा है...',
    'clearCacheHint':
        'ऐप डाउनलोड डायरेक्टरी में कैश फाइलें साफ़ करने के लिए टैप करें।',
    'cacheFootnote':
        'यह केवल ऐप-प्रबंधित डाउनलोड डायरेक्टरी की फाइलें साफ़ करता है। Photos में सहेजी गई या सिस्टम शेयर से भेजी गई प्रतियां प्रभावित नहीं होंगी।',
    'coverLoadFailed': 'कवर लोड नहीं हुआ',
    'noAudioTrack': 'ऑडियो नहीं',
    'downloadingPercent': 'डाउनलोड हो रहा है {progress}%',
    'connectingDownloadStream': 'डाउनलोड स्ट्रीम से कनेक्ट किया जा रहा है...',
    'download': 'डाउनलोड',
    'connectingDownload': 'डाउनलोड कनेक्शन बनाया जा रहा है...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': 'कार्यान्वयन विवरण',
    'footerDescription1':
        'यह संस्करण वेबसाइट को एम्बेड नहीं करता, बल्कि उसकी मुख्य क्षमता को दोहराता है: लिंक डालें, मेटाडेटा लाएं, डाउनलोड आइटम दिखाएं और लोकल सेव करें।',
    'footerDescription2':
        'फिलहाल YouTube, Douyin और iiilab / SnapAny द्वारा सार्वजनिक रूप से समर्थित TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo और Threads जैसे प्लेटफ़ॉर्म शामिल हैं। डायरेक्ट लिंक समय-सीमित होते हैं, इसलिए पार्स करने के बाद जल्द डाउनलोड करें।',
    'invalidVideoUrl': 'कृपया एक मान्य वीडियो लिंक दर्ज करें।',
    'unsupportedPlatformsMessage':
        'फिलहाल केवल YouTube, Douyin, Bilibili और iiilab / SnapAny द्वारा सार्वजनिक रूप से समर्थित TikTok, Twitter, Instagram, Facebook, Vimeo और Threads जैसे प्लेटफ़ॉर्म समर्थित हैं।',
    'noAvailableDownloadUrl': 'चयनित आइटम में मान्य फ़ाइल URL नहीं है।',
    'outputDirectoryUnavailable': 'उपलब्ध डाउनलोड डायरेक्टरी नहीं मिल सकी।',
    'unknownBitrate': 'अज्ञात बिटरेट',
    'defaultDownloadItem': 'डिफ़ॉल्ट डाउनलोड आइटम',
    'directLink': 'डायरेक्ट लिंक',
    'directLinkDownload': 'डायरेक्ट लिंक डाउनलोड',
    'withAudioTrack': 'ऑडियो सहित',
    'videoOnly': 'केवल वीडियो',
    'separatedAudioTrack': 'अलग ऑडियो ट्रैक',
    'previewImage': 'प्रीव्यू इमेज',
    'originalImage': 'मूल इमेज',
    'pageCover': 'पेज कवर',
    'pageFirstFrame': 'पहला फ्रेम',
    'sharePageCover': 'शेयर पेज कवर',
    'noWatermark': 'बिना वॉटरमार्क',
    'withWatermark': 'वॉटरमार्क सहित',
    'defaultCover': 'डिफ़ॉल्ट कवर',
    'unavailableMessage':
        'यह वीडियो उपलब्ध नहीं है, या मौजूदा नेटवर्क YouTube मीडिया स्ट्रीम सीधे नहीं ला पा रहा है।',
    'liveStreamNotSupported':
        'लाइव स्ट्रीम के लिए ऑफलाइन डाउनलोड अभी समर्थित नहीं है।',
    'highResWarning':
        '1080p से ऊपर की स्ट्रीम अक्सर केवल वीडियो होती हैं। सीधे चलाने के लिए इन्हें ऑडियो से मर्ज करें।',
    'parseServiceExtraLimit':
        'पार्स सेवा पर अतिरिक्त प्रतिबंध सक्रिय है। कृपया बाद में फिर प्रयास करें।',
    'parseServiceNoResult': 'पार्स सेवा ने उपयोगी परिणाम नहीं लौटाया।',
    'parseServiceNoMedia':
        'इस सामग्री के लिए कोई डाउनलोड योग्य मीडिया नहीं मिला।',
    'snapAnyNoResult': 'SnapAny ने उपयोगी परिणाम नहीं लौटाया।',
    'snapAnyNoMedia': 'SnapAny में कोई डाउनलोड योग्य मीडिया नहीं मिला।',
    'ageRestricted':
        'यह वीडियो आयु-सीमित है और मौजूदा पार्सिंग तरीका इसकी स्ट्रीम तक नहीं पहुंच सकता।',
    'privateVideo': 'यह वीडियो निजी है और डाउनलोड नहीं किया जा सकता।',
    'membersOnlyVideo':
        'यह वीडियो केवल सदस्य-विशेष है और अभी डाउनलोड नहीं किया जा सकता।',
    'regionRestricted':
        'यह वीडियो मौजूदा नेटवर्क क्षेत्र के लिए क्षेत्र-सीमित है।',
    'signInRequired':
        'इस वीडियो के लिए लॉग-इन सत्र चाहिए, जो यहां उपलब्ध नहीं है।',
    'iiilabUnsupportedLink':
        'यह लिंक iiilab द्वारा वर्तमान में समर्थित प्लेटफ़ॉर्म सूची में नहीं है।',
    'snapAnyUnsupportedLink':
        'यह लिंक SnapAny द्वारा वर्तमान में समर्थित प्लेटफ़ॉर्म सूची में नहीं है।',
    'douyinStructureChanged':
        'Douyin पेज की संरचना बदल गई है और अभी पार्स नहीं की जा सकती।',
    'bilibiliStructureChanged':
        'Bilibili पेज की संरचना बदल गई है और अभी पार्स नहीं की जा सकती।',
    'parseServiceFormatChanged':
        'पार्स सेवा ने असामान्य डेटा प्रारूप लौटाया है और अभी संभाला नहीं जा सकता।',
    'snapAnyFormatChanged':
        'SnapAny ने असामान्य डेटा प्रारूप लौटाया है और अभी संभाला नहीं जा सकता।',
    'douyinNoRouterData':
        'Douyin पेज पर पार्स करने योग्य route डेटा नहीं मिला।',
    'douyinRouteDataInvalid': 'Douyin route डेटा अमान्य है।',
    'douyinLoaderDataMissing': 'Douyin पेज में loaderData नहीं है।',
    'douyinNoVideoInfo': 'Douyin पेज पर वीडियो जानकारी नहीं मिली।',
    'douyinNoShareData':
        'मौजूदा Douyin वीडियो में उपयोगी share-page डेटा नहीं है।',
    'douyinNoPageContent': 'Douyin पेज ने पार्स करने योग्य सामग्री नहीं लौटाई।',
    'douyinNoDownloadAddress':
        'मौजूदा Douyin वीडियो में उपयोगी डाउनलोड URL नहीं हैं।',
    'bilibiliShortLinkInvalid':
        'शॉर्ट लिंक उपयोगी Bilibili वीडियो URL में resolve नहीं हुआ।',
    'bilibiliNoPageContent':
        'Bilibili पेज ने पार्स करने योग्य सामग्री नहीं लौटाई।',
    'bilibiliNoVideoInfo': 'Bilibili पेज पर उपयोगी वीडियो जानकारी नहीं मिली।',
    'bilibiliNoDownloadAddress':
        'मौजूदा Bilibili वीडियो में उपयोगी डाउनलोड URL नहीं हैं।',
    'bilibiliNoCover': 'मौजूदा Bilibili वीडियो में उपयोगी कवर इमेज नहीं है।',
    'bilibiliNoVideoStream':
        'मौजूदा Bilibili वीडियो में उपयोगी वीडियो स्ट्रीम नहीं है।',
    'platformDouyin': 'Douyin',
    'platformBilibili': 'Bilibili',
    'platformWeiboGroup': 'Weibo / Miaopai / Oasis',
    'platformZuiyou': 'Zuiyou',
    'platformWeishi': 'Weishi',
    'platformKg': 'K Song',
    'platformQuanmin': 'Quanmin Short Video',
    'platformMomo': 'Momo',
    'platformMeipai': 'Meipai',
    'platformMusic163': 'NetEase Music',
    'platformQutoutiao': 'Qutoutiao',
    'platformInke': 'Inke',
    'platformXiaoying': 'Xiaoying / VivaVideo',
    'platformPearVideo': 'Pear Video',
    'invalidPlatformUrl': 'कृपया मान्य {platform} लिंक दर्ज करें।',
    'noPageContent': '{platform} पेज ने पार्स करने योग्य सामग्री नहीं लौटाई।',
    'noVideoInfo':
        'मौजूदा {platform} सामग्री के लिए उपयोगी वीडियो जानकारी नहीं मिली।',
    'noDownloadAddress':
        'मौजूदा {platform} सामग्री उपयोगी डाउनलोड URL नहीं देती।',
    'noCoverForPlatform':
        'मौजूदा {platform} सामग्री उपयोगी कवर इमेज नहीं देती।',
    'noVideoStreamForPlatform':
        'मौजूदा {platform} सामग्री उपयोगी वीडियो स्ट्रीम नहीं देती।',
    'parseFailed': '{platform} पार्स विफल: {error}',
    'timeoutMessage': '{platform} से कनेक्ट करते समय समय समाप्त हुआ। {detail}',
    'networkUnavailable': 'यह डिवाइस {platform} तक नहीं पहुंच सकता। {detail}',
    'handshakeFailed':
        '{platform} के साथ सुरक्षित कनेक्शन स्थापित नहीं हो सका। {detail}',
    'requestRejected': '{platform} ने अभी इस अनुरोध को अस्वीकार किया। {detail}',
    'requestFailed': '{platform} अनुरोध विफल: {message}',
    'metricViews': 'व्यू',
    'metricLikes': 'लाइक',
    'metricShares': 'शेयर',
    'videoQualityTitle': 'वीडियो {quality}',
    'audioBitrateTitle': 'ऑडियो {bitrate}',
    'highResVideoTitle': 'हाई-रेज़ {quality}',
    'watermarkedVideoTitle': 'वीडियो {quality} (वॉटरमार्क)',
    'videoTitleWithIndex': 'वीडियो {index}',
    'imageTitle': 'इमेज',
    'imageTitleWithIndex': 'इमेज {index}',
    'audioTitle': 'ऑडियो',
    'videoTitle': 'वीडियो',
    'directVideoTitle': 'डायरेक्ट वीडियो',
    'thumbnailTitle': 'थंबनेल',
    'coverTitle': 'कवर इमेज',
    'firstFrameTitle': 'पहला फ्रेम',
    'originalQuality': 'मूल गुणवत्ता',
    'contentTitle': '{platform} सामग्री',
    'parseResultTitle': '{platform} पार्स परिणाम',
    'defaultAuthor': '{platform} लेखक',
    'bilibiliWarning':
        'यह परिणाम सीधे {platform} मोबाइल पेज से पार्स किया गया है। वीडियो और कवर लिंक समय-सीमित हैं, इसलिए पार्स के तुरंत बाद डाउनलोड करें।',
    'douyinWarning':
        'यह परिणाम {platform} share page से पार्स किया गया है और केवल direct MP4 video तथा cover image देता है। अलग ऑडियो और अधिक quality अभी उपलब्ध नहीं हैं।',
    'iiilabWarning':
        'यह परिणाम iiilab parser से आता है और direct links लौटाता है जो सामान्यतः समय-सीमित होते हैं। पार्स के बाद जल्द डाउनलोड करें।',
    'snapAnyWarning':
        'यह परिणाम SnapAny parser से आता है और direct links लौटाता है जो सामान्यतः समय-सीमित होते हैं। पार्स के बाद जल्द डाउनलोड करें।',
    'overseasNetworkWarning':
        '{platform} सामग्री डाउनलोड करना अभी भी वर्तमान नेटवर्क पर निर्भर करता है।',
    'muxingWarning':
        'कुछ हाई-रेज़ वीडियो में ऑडियो नहीं होता। सीधे प्लेबैक के लिए इन्हें ऑडियो ट्रैक के साथ मर्ज करें।',
    'youtubeTimeoutDetail':
        'मौजूदा नेटवर्क आमतौर पर YouTube तक स्थिर पहुंच नहीं देता।',
    'youtubeNetworkDetail':
        'सुनिश्चित करें कि मौजूदा नेटवर्क YouTube तक पहुंच सकता है, फिर दोबारा प्रयास करें।',
    'youtubeHandshakeDetail': 'मौजूदा नेटवर्क या प्रॉक्सी कॉन्फ़िगरेशन जांचें।',
    'douyinTimeoutDetail':
        'मौजूदा नेटवर्क अक्सर Douyin share page तक स्थिर पहुंच नहीं देता।',
    'douyinNetworkDetail':
        'सुनिश्चित करें कि मौजूदा नेटवर्क Douyin तक पहुंच सकता है, फिर दोबारा प्रयास करें।',
    'douyinHandshakeDetail': 'मौजूदा नेटवर्क या प्रॉक्सी कॉन्फ़िगरेशन जांचें।',
    'bilibiliTimeoutDetail': 'कृपया बाद में फिर प्रयास करें।',
    'bilibiliNetworkDetail': 'नेटवर्क कनेक्शन जांचें और फिर प्रयास करें।',
    'bilibiliHandshakeDetail': 'मौजूदा नेटवर्क वातावरण जांचें।',
    'parserTimeoutDetail': 'कृपया बाद में फिर प्रयास करें।',
    'parserNetworkDetail': 'नेटवर्क कनेक्शन जांचें और फिर प्रयास करें।',
    'parserHandshakeDetail': 'मौजूदा नेटवर्क वातावरण जांचें।',
    'retryLaterDetail': 'थोड़ी देर बाद फिर प्रयास करना अधिक स्थिर रहेगा।',
    'snapAnyRetryLaterDetail':
        'थोड़ा इंतजार करके फिर प्रयास करें, सफलता अधिक स्थिर रहेगी।',
    'snapAnyRateLimited':
        'SnapAny वर्तमान में अनुरोध आवृत्ति सीमित कर रहा है। कृपया बाद में फिर प्रयास करें।',
  },
  _AppLanguage.th: {
    'settingsCenter': 'การตั้งค่า',
    'language': 'ภาษา',
    'languageSettingHint': 'เปิดหน้าการเลือกภาษาและเปลี่ยนภาษาที่แสดงในแอป',
    'selectLanguage': 'เลือกภาษา',
    'selectLanguageHint': 'เลือกภาษาใหม่แล้วกดยืนยันเพื่อใช้งานทันที',
    'displayMode': 'โหมดการแสดงผล',
    'displayModeSettingHint':
        'สลับระหว่างโหมดตามโทรศัพท์ โหมดสว่าง หรือโหมดมืด',
    'selectDisplayMode': 'เลือกโหมดการแสดงผล',
    'selectDisplayModeHint': 'เลือกโหมดใหม่แล้วกดยืนยันเพื่อใช้งานทันที',
    'followPhoneMode': 'ตามโทรศัพท์',
    'lightMode': 'โหมดสว่าง',
    'darkMode': 'โหมดมืด',
    'confirm': 'ยืนยัน',
    'parseVideo': 'แยกวิเคราะห์วิดีโอ',
    'parsing': 'กำลังแยกวิเคราะห์...',
    'parseVideoIntro':
        'จัดการลิงก์ YouTube, Douyin และแพลตฟอร์มที่ iiilab / SnapAny รองรับแบบสาธารณะในตอนนี้ เช่น TikTok, Bilibili, Twitter, Instagram, Facebook, Vimeo และ Threads จากจุดเดียว',
    'videoLinkHint':
        'วางลิงก์วิดีโอ เช่น YouTube, Douyin, TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo...',
    'pasteClipboard': 'วางจากคลิปบอร์ด',
    'pasteVideoLinkFirst': 'โปรดวางลิงก์วิดีโอก่อน',
    'savedToFile': 'บันทึกไปยัง {fileName} แล้ว',
    'open': 'เปิด',
    'downloadFailed': 'ดาวน์โหลดล้มเหลว: {error}',
    'cannotOpenFile': 'ไม่สามารถเปิดไฟล์โดยตรงได้: {reason}',
    'savedToPhotosIos': 'บันทึกลงแอปรูปภาพแล้ว เปิดแอปรูปภาพเพื่อดู',
    'savedToPhotos': 'บันทึกลงคลังรูปภาพแล้ว',
    'saveToGalleryFailed': 'บันทึกลงคลังรูปภาพล้มเหลว: {error}',
    'shareFile': 'แชร์ไฟล์: {fileName}',
    'shareFailed': 'แชร์ล้มเหลว: {error}',
    'galleryPermissionDenied':
        'ไม่มีสิทธิ์เข้าถึงรูปภาพ โปรดอนุญาตในตั้งค่าระบบ',
    'galleryNotEnoughSpace': 'พื้นที่ว่างบนอุปกรณ์ไม่เพียงพอ',
    'galleryUnsupportedFormat':
        'รูปแบบไฟล์นี้ไม่รองรับการบันทึกลงคลังรูปภาพของระบบ',
    'galleryUnknownError': 'คลังรูปภาพของระบบส่งข้อผิดพลาดที่ไม่ทราบสาเหตุ',
    'heroPlatforms': 'YouTube + Douyin + หลายแพลตฟอร์ม',
    'heroInProgress': 'กำลังดำเนินการ',
    'heroReady': 'พร้อมใช้งาน',
    'heroDescription':
        'วางลิงก์เพื่อแยกภาพปกและลิงก์ตรงที่ดาวน์โหลดได้สำหรับวิดีโอ เสียง รูปภาพ หรือหน้าการแชร์ แล้วบันทึกในเครื่อง บันทึกลงคลังรูปภาพ หรือแชร์ผ่านระบบ',
    'quickDownload': 'ดาวน์โหลดด่วน',
    'quickDownloadSubtitle':
        'รายการที่ใช้บ่อยที่สุดจะแสดงที่นี่และเปลี่ยนตามความสามารถของแต่ละแพลตฟอร์ม',
    'playableVideos': 'สตรีมวิดีโอที่เล่นได้ทันที',
    'playableVideosSubtitle': 'มีเสียง เปิดเล่นได้ทันทีหลังดาวน์โหลด',
    'audioStreams': 'สตรีมเสียงแยก',
    'audioStreamsSubtitle':
        'เหมาะเมื่อคุณต้องการเฉพาะเสียงหรือจะนำไปรวมภายหลัง',
    'highResVideos': 'สตรีมวิดีโอความละเอียดสูง',
    'highResVideosSubtitle': 'มักเป็น 1080p / 4K แต่โดยทั่วไปไม่มีแทร็กเสียง',
    'imageDownloads': 'ดาวน์โหลดรูปภาพ / ภาพปก',
    'imageDownloadsSubtitle': 'รูปภาพต้นฉบับและภาพปกจะถูกรวมไว้ที่นี่',
    'clearCache': 'ล้างแคช',
    'cacheDialogContent':
        'ขนาดแคชปัจจุบันประมาณ {cacheSize} หลังจากล้างแล้ว ไฟล์ที่ดาวน์โหลดภายในแอปแต่ยังไม่ได้บันทึกไว้ที่อื่นจะถูกลบ',
    'emptyCacheDialogContent':
        'ขณะนี้ไม่มีแคชให้ล้าง ต้องการรีเฟรชสถานะแคชต่อหรือไม่',
    'cancel': 'ยกเลิก',
    'clear': 'ล้าง',
    'refresh': 'รีเฟรช',
    'cacheCleared': 'ล้างแคชแล้ว {cacheSize}',
    'noCache': 'ขณะนี้ไม่มีแคชให้ล้าง',
    'clearCacheFailed': 'ล้างแคชล้มเหลว: {error}',
    'calculating': 'กำลังคำนวณ...',
    'cacheSize': 'ขนาดแคช',
    'clearingCache': 'กำลังล้างแคชของแอป...',
    'clearCacheHint': 'แตะเพื่อล้างไฟล์แคชในโฟลเดอร์ดาวน์โหลดของแอป',
    'cacheFootnote':
        'การล้างนี้จะลบเฉพาะไฟล์ในโฟลเดอร์ดาวน์โหลดที่แอปจัดการไว้เท่านั้น สำเนาที่บันทึกลงรูปภาพหรือแชร์ออกไปแล้วจะไม่ได้รับผลกระทบ',
    'coverLoadFailed': 'โหลดภาพปกล้มเหลว',
    'noAudioTrack': 'ไม่มีเสียง',
    'downloadingPercent': 'กำลังดาวน์โหลด {progress}%',
    'connectingDownloadStream': 'กำลังเชื่อมต่อสตรีมดาวน์โหลด...',
    'download': 'ดาวน์โหลด',
    'connectingDownload': 'กำลังสร้างการเชื่อมต่อดาวน์โหลด...',
    'downloadConnectionProgress': '{progress}%',
    'footerTitle': 'คำอธิบายการทำงาน',
    'footerDescription1':
        'เวอร์ชันนี้ทำซ้ำความสามารถหลักของเว็บไซต์แทนการฝังหน้าเว็บ: ใส่ลิงก์ ดึงเมทาดาทา แสดงรายการดาวน์โหลด และบันทึกไว้ในเครื่อง',
    'footerDescription2':
        'ขณะนี้รองรับ YouTube, Douyin และแพลตฟอร์มที่ iiilab / SnapAny รองรับแบบสาธารณะ เช่น TikTok, Bilibili, Weibo, Twitter, Instagram, Facebook, Vimeo และ Threads ลิงก์ตรงมีอายุจำกัด ควรดาวน์โหลดโดยเร็วหลังแยกวิเคราะห์',
    'invalidVideoUrl': 'กรุณาใส่ลิงก์วิดีโอที่ถูกต้อง',
    'unsupportedPlatformsMessage':
        'ขณะนี้รองรับเฉพาะ YouTube, Douyin, Bilibili และแพลตฟอร์มที่ iiilab / SnapAny รองรับแบบสาธารณะ เช่น TikTok, Twitter, Instagram, Facebook, Vimeo และ Threads',
    'noAvailableDownloadUrl': 'รายการดาวน์โหลดนี้ไม่มี URL ไฟล์ที่ใช้งานได้',
    'outputDirectoryUnavailable': 'ไม่พบโฟลเดอร์ดาวน์โหลดที่ใช้งานได้',
    'unknownBitrate': 'ไม่ทราบบิตเรต',
    'defaultDownloadItem': 'รายการดาวน์โหลดเริ่มต้น',
    'directLink': 'ลิงก์ตรง',
    'directLinkDownload': 'ดาวน์โหลดลิงก์ตรง',
    'withAudioTrack': 'มีเสียง',
    'videoOnly': 'วิดีโอเท่านั้น',
    'separatedAudioTrack': 'แทร็กเสียงแยก',
    'previewImage': 'ภาพตัวอย่าง',
    'originalImage': 'ภาพต้นฉบับ',
    'pageCover': 'ภาพปกหน้า',
    'pageFirstFrame': 'เฟรมแรก',
    'sharePageCover': 'ภาพปกหน้าการแชร์',
    'noWatermark': 'ไม่มีลายน้ำ',
    'withWatermark': 'มีลายน้ำ',
    'defaultCover': 'ภาพปกเริ่มต้น',
    'unavailableMessage':
        'วิดีโอนี้ไม่พร้อมใช้งาน หรือเครือข่ายปัจจุบันไม่สามารถดึงสตรีมสื่อของ YouTube ได้โดยตรง',
    'liveStreamNotSupported':
        'ขณะนี้ยังไม่รองรับการดาวน์โหลดออฟไลน์สำหรับไลฟ์สตรีม',
    'highResWarning':
        'สตรีมที่สูงกว่า 1080p มักเป็นวิดีโออย่างเดียว หากต้องการให้เล่นได้ทันทีให้รวมกับเสียงก่อน',
    'parseServiceExtraLimit':
        'บริการแยกวิเคราะห์มีข้อจำกัดเพิ่มเติมอยู่ในขณะนี้ โปรดลองอีกครั้งภายหลัง',
    'parseServiceNoResult':
        'บริการแยกวิเคราะห์ไม่ได้ส่งผลลัพธ์ที่ใช้งานได้กลับมา',
    'parseServiceNoMedia': 'ไม่พบสื่อที่ดาวน์โหลดได้สำหรับเนื้อหานี้',
    'snapAnyNoResult': 'SnapAny ไม่ได้ส่งผลลัพธ์ที่ใช้งานได้กลับมา',
    'snapAnyNoMedia': 'ไม่พบสื่อที่ดาวน์โหลดได้ใน SnapAny',
    'ageRestricted':
        'วิดีโอนี้มีการจำกัดอายุ และวิธีแยกวิเคราะห์ปัจจุบันไม่สามารถเข้าถึงสตรีมได้',
    'privateVideo': 'วิดีโอนี้เป็นแบบส่วนตัวและไม่สามารถดาวน์โหลดได้',
    'membersOnlyVideo':
        'วิดีโอนี้เป็นเนื้อหาสำหรับสมาชิกเท่านั้นและยังไม่สามารถดาวน์โหลดได้',
    'regionRestricted': 'วิดีโอนี้ถูกจำกัดตามภูมิภาคสำหรับเครือข่ายปัจจุบัน',
    'signInRequired':
        'วิดีโอนี้ต้องใช้สถานะการเข้าสู่ระบบ ซึ่งไม่พร้อมใช้งานที่นี่',
    'iiilabUnsupportedLink':
        'ลิงก์นี้ไม่อยู่ในรายชื่อแพลตฟอร์มที่ iiilab รองรับในตอนนี้',
    'snapAnyUnsupportedLink':
        'ลิงก์นี้ไม่อยู่ในรายชื่อแพลตฟอร์มที่ SnapAny รองรับในตอนนี้',
    'douyinStructureChanged':
        'โครงสร้างหน้า Douyin เปลี่ยนไปและยังไม่สามารถแยกวิเคราะห์ได้',
    'bilibiliStructureChanged':
        'โครงสร้างหน้า Bilibili เปลี่ยนไปและยังไม่สามารถแยกวิเคราะห์ได้',
    'parseServiceFormatChanged':
        'บริการแยกวิเคราะห์ส่งรูปแบบข้อมูลที่ผิดปกติกลับมาและยังไม่สามารถจัดการได้',
    'snapAnyFormatChanged':
        'SnapAny ส่งรูปแบบข้อมูลที่ผิดปกติกลับมาและยังไม่สามารถจัดการได้',
    'douyinNoRouterData':
        'ไม่พบข้อมูล route ที่สามารถแยกวิเคราะห์ได้บนหน้า Douyin',
    'douyinRouteDataInvalid': 'ข้อมูล route ของ Douyin ไม่ถูกต้อง',
    'douyinLoaderDataMissing': 'หน้า Douyin ไม่มี loaderData',
    'douyinNoVideoInfo': 'ไม่พบข้อมูลวิดีโอบนหน้า Douyin',
    'douyinNoShareData':
        'วิดีโอ Douyin ปัจจุบันไม่มีข้อมูลหน้าการแชร์ที่ใช้งานได้',
    'douyinNoPageContent':
        'หน้า Douyin ไม่ได้ส่งเนื้อหาที่แยกวิเคราะห์ได้กลับมา',
    'douyinNoDownloadAddress':
        'วิดีโอ Douyin ปัจจุบันไม่มี URL ดาวน์โหลดที่ใช้งานได้',
    'bilibiliShortLinkInvalid':
        'ลิงก์สั้นไม่สามารถแปลงเป็น URL วิดีโอ Bilibili ที่ใช้งานได้',
    'bilibiliNoPageContent':
        'หน้า Bilibili ไม่ได้ส่งเนื้อหาที่แยกวิเคราะห์ได้กลับมา',
    'bilibiliNoVideoInfo': 'ไม่พบข้อมูลวิดีโอที่ใช้งานได้บนหน้า Bilibili',
    'bilibiliNoDownloadAddress':
        'วิดีโอ Bilibili ปัจจุบันไม่มี URL ดาวน์โหลดที่ใช้งานได้',
    'bilibiliNoCover': 'วิดีโอ Bilibili ปัจจุบันไม่มีภาพปกที่ใช้งานได้',
    'bilibiliNoVideoStream':
        'วิดีโอ Bilibili ปัจจุบันไม่มีสตรีมวิดีโอที่ใช้งานได้',
    'platformDouyin': 'Douyin',
    'platformBilibili': 'Bilibili',
    'platformWeiboGroup': 'Weibo / Miaopai / Oasis',
    'platformZuiyou': 'Zuiyou',
    'platformWeishi': 'Weishi',
    'platformKg': 'K Song',
    'platformQuanmin': 'Quanmin Short Video',
    'platformMomo': 'Momo',
    'platformMeipai': 'Meipai',
    'platformMusic163': 'NetEase Music',
    'platformQutoutiao': 'Qutoutiao',
    'platformInke': 'Inke',
    'platformXiaoying': 'Xiaoying / VivaVideo',
    'platformPearVideo': 'Pear Video',
    'invalidPlatformUrl': 'กรุณาใส่ลิงก์ {platform} ที่ถูกต้อง',
    'noPageContent': 'หน้า {platform} ไม่ได้ส่งเนื้อหาที่แยกวิเคราะห์ได้กลับมา',
    'noVideoInfo':
        'ไม่พบข้อมูลวิดีโอที่ใช้งานได้สำหรับเนื้อหา {platform} ปัจจุบัน',
    'noDownloadAddress':
        'เนื้อหา {platform} ปัจจุบันไม่มี URL ดาวน์โหลดที่ใช้งานได้',
    'noCoverForPlatform': 'เนื้อหา {platform} ปัจจุบันไม่มีภาพปกที่ใช้งานได้',
    'noVideoStreamForPlatform':
        'เนื้อหา {platform} ปัจจุบันไม่มีสตรีมวิดีโอที่ใช้งานได้',
    'parseFailed': 'แยกวิเคราะห์ {platform} ล้มเหลว: {error}',
    'timeoutMessage': 'หมดเวลาขณะเชื่อมต่อไปยัง {platform} {detail}',
    'networkUnavailable':
        'อุปกรณ์นี้ไม่สามารถเชื่อมต่อไปยัง {platform} ได้ {detail}',
    'handshakeFailed':
        'ไม่สามารถสร้างการเชื่อมต่อที่ปลอดภัยกับ {platform} ได้ {detail}',
    'requestRejected': '{platform} ปฏิเสธคำขอนี้ชั่วคราว {detail}',
    'requestFailed': 'คำขอไปยัง {platform} ล้มเหลว: {message}',
    'metricViews': 'ครั้งที่รับชม',
    'metricLikes': 'ครั้งที่กดถูกใจ',
    'metricShares': 'ครั้งที่แชร์',
    'videoQualityTitle': 'วิดีโอ {quality}',
    'audioBitrateTitle': 'เสียง {bitrate}',
    'highResVideoTitle': 'ความละเอียดสูง {quality}',
    'watermarkedVideoTitle': 'วิดีโอ {quality} (ลายน้ำ)',
    'videoTitleWithIndex': 'วิดีโอ {index}',
    'imageTitle': 'รูปภาพ',
    'imageTitleWithIndex': 'รูปภาพ {index}',
    'audioTitle': 'เสียง',
    'videoTitle': 'วิดีโอ',
    'directVideoTitle': 'วิดีโอลิงก์ตรง',
    'thumbnailTitle': 'ภาพตัวอย่าง',
    'coverTitle': 'ภาพปก',
    'firstFrameTitle': 'เฟรมแรก',
    'originalQuality': 'คุณภาพต้นฉบับ',
    'contentTitle': 'เนื้อหา {platform}',
    'parseResultTitle': 'ผลการแยกวิเคราะห์ {platform}',
    'defaultAuthor': 'ผู้สร้าง {platform}',
    'bilibiliWarning':
        'ผลลัพธ์นี้แยกวิเคราะห์โดยตรงจากหน้า mobile ของ {platform} ลิงก์วิดีโอและภาพปกมีอายุจำกัด ควรดาวน์โหลดโดยเร็วหลังแยกวิเคราะห์',
    'douyinWarning':
        'ผลลัพธ์นี้แยกวิเคราะห์จากหน้าแชร์ของ {platform} และให้เฉพาะวิดีโอ MP4 แบบตรงกับภาพปกเท่านั้น ยังไม่มีเสียงแยกหรือคุณภาพเพิ่มเติม',
    'iiilabWarning':
        'ผลลัพธ์นี้มาจากตัวแยกวิเคราะห์ iiilab และส่งลิงก์ตรงที่มักมีอายุจำกัด ควรดาวน์โหลดโดยเร็วหลังแยกวิเคราะห์',
    'snapAnyWarning':
        'ผลลัพธ์นี้มาจากตัวแยกวิเคราะห์ SnapAny และส่งลิงก์ตรงที่มักมีอายุจำกัด ควรดาวน์โหลดโดยเร็วหลังแยกวิเคราะห์',
    'overseasNetworkWarning':
        'การดาวน์โหลดเนื้อหา {platform} ยังขึ้นอยู่กับเครือข่ายปัจจุบัน',
    'muxingWarning':
        'วิดีโอความละเอียดสูงบางรายการไม่มีเสียง หากต้องการให้เล่นได้ทันทีให้รวมกับแทร็กเสียงก่อน',
    'youtubeTimeoutDetail': 'เครือข่ายปัจจุบันมักเข้าถึง YouTube ได้ไม่เสถียร',
    'youtubeNetworkDetail':
        'ตรวจสอบว่าเครือข่ายปัจจุบันเข้าถึง YouTube ได้แล้วลองใหม่อีกครั้ง',
    'youtubeHandshakeDetail': 'ตรวจสอบเครือข่ายหรือการตั้งค่าพร็อกซีปัจจุบัน',
    'douyinTimeoutDetail':
        'เครือข่ายปัจจุบันมักเข้าถึงหน้าการแชร์ของ Douyin ได้ไม่เสถียร',
    'douyinNetworkDetail':
        'ตรวจสอบว่าเครือข่ายปัจจุบันเข้าถึง Douyin ได้แล้วลองใหม่อีกครั้ง',
    'douyinHandshakeDetail': 'ตรวจสอบเครือข่ายหรือการตั้งค่าพร็อกซีปัจจุบัน',
    'bilibiliTimeoutDetail': 'โปรดลองอีกครั้งภายหลัง',
    'bilibiliNetworkDetail': 'ตรวจสอบการเชื่อมต่อเครือข่ายแล้วลองอีกครั้ง',
    'bilibiliHandshakeDetail': 'ตรวจสอบสภาพแวดล้อมเครือข่ายปัจจุบัน',
    'parserTimeoutDetail': 'โปรดลองอีกครั้งภายหลัง',
    'parserNetworkDetail': 'ตรวจสอบการเชื่อมต่อเครือข่ายแล้วลองอีกครั้ง',
    'parserHandshakeDetail': 'ตรวจสอบสภาพแวดล้อมเครือข่ายปัจจุบัน',
    'retryLaterDetail': 'ลองใหม่ภายหลังจะเสถียรกว่า',
    'snapAnyRetryLaterDetail': 'รอสักครู่แล้วลองใหม่เพื่อความเสถียรที่ดีกว่า',
    'snapAnyRateLimited':
        'SnapAny กำลังจำกัดความถี่ของคำขอในขณะนี้ โปรดลองอีกครั้งภายหลัง',
  },
};
