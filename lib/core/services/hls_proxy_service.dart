import 'dart:io';
import 'package:flutter/foundation.dart';
import 'wordpress_service.dart';

/// A local HTTP proxy server that intercepts ALL HLS requests and injects
/// the required security headers (x-app-token, Referer, etc.) into each one.
///
/// This solves the problem where media_kit/libmpv sends custom headers only
/// for the initial .m3u8 request, but NOT for the AES-128 key or .ts segments.
///
/// How it works:
///   1. Start a local server on localhost:PORT
///   2. Give media_kit a proxied URL: http://localhost:PORT/hls?url=ORIGINAL_URL
///   3. For every request, this proxy fetches the real URL with all security headers
///   4. For .m3u8 files, it rewrites the key URI to also go through the proxy
///   5. media_kit plays the video perfectly with full decryption!
class HlsProxyService {
  HttpServer? _server;
  int _port = 0;
  String? _keyToken;

  static const _appToken = 'JEMY_SECURE_12345';
  static const _referer = 'https://www.jemypedia.com/';
  static const _origin = 'https://www.jemypedia.com';
  static const _userAgent = 'JemyPediaPlayer/JEMY_SECURE_12345';

  int get port => _port;
  bool get isRunning => _server != null;

  /// Store the key token for the active playback session
  void setKeyToken(String? token) {
    _keyToken = token;
  }

  /// Start the local proxy server. Call this once (e.g., in main.dart).
  Future<void> start() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      debugPrint('🔥 HLS Proxy started on port $_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('HLS Proxy error: $e');
      });
    } catch (e) {
      debugPrint('Failed to start HLS Proxy: $e');
    }
  }

  /// Stop the proxy server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
  }

  /// Convert an original HLS URL into a proxied URL.
  /// Returns the original URL unchanged if proxy is not running.
  String proxyUrl(String originalUrl) {
    if (_server == null || _port == 0) return originalUrl;
    final encoded = Uri.encodeComponent(originalUrl);
    return 'http://127.0.0.1:$_port/hls?url=$encoded';
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Extract the real URL from query parameter
    final rawUrl = request.uri.queryParameters['url'];
    if (rawUrl == null || rawUrl.isEmpty) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }

    final targetUri = Uri.tryParse(rawUrl);
    if (targetUri == null) {
      request.response.statusCode = 400;
      await request.response.close();
      return;
    }

    try {
      Uri finalTargetUri = targetUri;

      // If the player is requesting the encryption key, dynamically fetch a one-time token
      if (rawUrl.toLowerCase().contains('.key')) {
        final token = await WordPressService().generateVideoToken();
        if (token != null) {
          finalTargetUri = Uri.parse('${WordPressService.domain}/video_key.php?token=$token');
        }
      }

      // Create HTTP client to fetch the real resource
      final client = HttpClient();
      client.userAgent = _userAgent;

      final proxyReq = await client.getUrl(finalTargetUri);

      // Inject ALL security headers into every upstream request
      proxyReq.headers.set('Referer', _referer);
      proxyReq.headers.set('Origin', _origin);
      proxyReq.headers.set('User-Agent', _userAgent);
      proxyReq.headers.set('x-app-token', _appToken);
      if (_keyToken != null && _keyToken!.isNotEmpty) {
        proxyReq.headers.set('x-key-token', _keyToken!);
      }

      final proxyResp = await proxyReq.close();

      // Determine content type from response
      final contentType = proxyResp.headers.contentType?.mimeType ?? 'application/octet-stream';

      // If upstream failed, forward the error status code directly to the player
      if (proxyResp.statusCode != 200) {
        request.response.statusCode = proxyResp.statusCode;
        request.response.headers.contentType = ContentType.parse(contentType);
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        await proxyResp.pipe(request.response);
        client.close();
        return;
      }

      final isM3u8 = contentType.contains('mpegurl') ||
          rawUrl.toLowerCase().contains('.m3u8');

      if (isM3u8) {
        // Read and rewrite the .m3u8 content so all URIs go through our proxy
        final bodyBytes = await _collectBytes(proxyResp);
        final m3u8Content = String.fromCharCodes(bodyBytes);
        final rewritten = _rewriteM3u8(m3u8Content, rawUrl);

        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl');
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        request.response.write(rewritten);
      } else {
        // For .ts segments and .key files - stream them directly
        request.response.statusCode = proxyResp.statusCode;
        request.response.headers.contentType =
            ContentType.parse(contentType);
        request.response.headers.set('Access-Control-Allow-Origin', '*');
        await proxyResp.pipe(request.response);
        client.close();
        return; // pipe() closes the response
      }

      await request.response.close();
      client.close();
    } catch (e) {
      debugPrint('HLS Proxy request error for $rawUrl: $e');
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Rewrite an m3u8 file so that:
  ///  - EXT-X-KEY URI lines point to our local proxy
  ///  - Relative .ts segment URLs are made absolute then proxied
  String _rewriteM3u8(String content, String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    final lines = content.split('\n');
    final result = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('#EXT-X-KEY:')) {
        // Rewrite the URI inside EXT-X-KEY
        final rewritten = trimmed.replaceAllMapped(
          RegExp(r'URI="([^"]+)"'),
          (match) {
            final keyUri = match.group(1)!;
            final absKeyUri = _resolveUrl(keyUri, baseUri);
            final proxied = proxyUrl(absKeyUri);
            return 'URI="$proxied"';
          },
        );
        result.add(rewritten);
      } else if (!trimmed.startsWith('#') && trimmed.isNotEmpty) {
        // Rewrite .ts segment URLs
        final absSegUri = _resolveUrl(trimmed, baseUri);
        result.add(proxyUrl(absSegUri));
      } else {
        result.add(line);
      }
    }

    return result.join('\n');
  }

  /// Resolve a potentially relative URL against a base URL.
  String _resolveUrl(String url, Uri base) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return base.resolve(url).toString();
  }

  Future<List<int>> _collectBytes(HttpClientResponse response) async {
    final chunks = <List<int>>[];
    await for (final chunk in response) {
      chunks.add(chunk);
    }
    return chunks.expand((c) => c).toList();
  }
}

/// Global singleton instance
final hlsProxy = HlsProxyService();
