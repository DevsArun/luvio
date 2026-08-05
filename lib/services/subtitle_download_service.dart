import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// One subtitle result returned by an online search.
class OnlineSubtitle {
  const OnlineSubtitle({
    required this.name,
    required this.language,
    required this.downloadUrl,
    this.rating,
  });

  final String name;
  final String language;
  final String downloadUrl;
  final double? rating;
}

/// Downloads subtitle files so they can be attached to the current video.
///
/// Two ways in:
///  * [downloadFromUrl] — paste any direct `.srt` / `.vtt` / `.ass` link.
///  * [search] — look the movie up on OpenSubtitles (needs a free API key,
///    entered once in Settings; without a key only direct links work).
class SubtitleDownloadService {
  static const String _apiBase = 'https://api.opensubtitles.com/api/v1';
  static const List<String> _allowedExtensions = <String>[
    '.srt',
    '.vtt',
    '.ass',
    '.ssa',
    '.sub',
  ];

  /// Saves the subtitle at [url] into the app's subtitle folder and returns
  /// the local file path, or null when the download fails.
  Future<String?> downloadFromUrl(String url, {String? preferredName}) async {
    final clean = url.trim();
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return null;
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = Duration(seconds: 20);
      final request = await client.getUrl(Uri.parse(clean));
      request.headers.set(HttpHeaders.userAgentHeader, 'LuvioPlayer/2.6');
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final bytes = await consolidateBytes(response);
      if (bytes.isEmpty) return null;

      final dir = await _subtitleDir();
      final name = _fileNameFor(clean, preferredName);
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Searches OpenSubtitles. Returns an empty list when no [apiKey] is set or
  /// the service is unreachable.
  Future<List<OnlineSubtitle>> search({
    required String query,
    required String apiKey,
    String languages = 'en',
  }) async {
    if (apiKey.trim().isEmpty || query.trim().isEmpty) return <OnlineSubtitle>[];

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = Duration(seconds: 20);
      final uri = Uri.parse(
        '$_apiBase/subtitles'
        '?query=${Uri.encodeQueryComponent(query.trim())}'
        '&languages=${Uri.encodeQueryComponent(languages)}',
      );
      final request = await client.getUrl(uri);
      request.headers.set('Api-Key', apiKey.trim());
      request.headers.set(HttpHeaders.userAgentHeader, 'LuvioPlayer v2.6');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      if (response.statusCode != 200) return <OnlineSubtitle>[];

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) return <OnlineSubtitle>[];
      final data = decoded['data'];
      if (data is! List) return <OnlineSubtitle>[];

      final results = <OnlineSubtitle>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final attrs = entry['attributes'];
        if (attrs is! Map) continue;
        final files = attrs['files'];
        String? fileId;
        if (files is List && files.isNotEmpty && files.first is Map) {
          fileId = '${(files.first as Map)['file_id'] ?? ''}';
        }
        if (fileId == null || fileId.isEmpty) continue;
        results.add(
          OnlineSubtitle(
            name: '${attrs['release'] ?? 'Subtitle'}',
            language: '${attrs['language'] ?? languages}',
            downloadUrl: '$_apiBase/download?file_id=$fileId',
            rating: double.tryParse('${attrs['ratings'] ?? ''}'),
          ),
        );
        if (results.length >= 25) break;
      }
      return results;
    } catch (_) {
      return <OnlineSubtitle>[];
    } finally {
      client?.close(force: true);
    }
  }

  /// Resolves an OpenSubtitles download ticket into a real file link, then
  /// saves it locally. Returns the local path, or null on failure.
  Future<String?> downloadSearchResult(
    OnlineSubtitle subtitle, {
    required String apiKey,
  }) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = Duration(seconds: 20);
      final request = await client.postUrl(Uri.parse(subtitle.downloadUrl));
      request.headers.set('Api-Key', apiKey.trim());
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.write(jsonEncode(<String, dynamic>{}));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final link = '${decoded['link'] ?? ''}';
      if (link.isEmpty) return null;
      return downloadFromUrl(link, preferredName: subtitle.name);
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  Future<Directory> _subtitleDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/subtitles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _fileNameFor(String url, String? preferredName) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    var extension = '.srt';
    final lower = url.toLowerCase();
    for (final candidate in _allowedExtensions) {
      if (lower.contains(candidate)) {
        extension = candidate;
        break;
      }
    }
    final base = (preferredName ?? 'subtitle')
        .replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '')
        .trim();
    final safe = base.isEmpty ? 'subtitle' : base;
    return '${safe}_$stamp$extension';
  }

  /// Collects the response body without pulling in extra packages.
  static Future<List<int>> consolidateBytes(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
}
