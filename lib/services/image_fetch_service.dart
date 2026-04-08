import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service that handles `[FETCH_IMAGE: "query"]` tags in AI output.
/// Uses Google Custom Search Images API when configured.
/// Falls back to FREE Wikimedia Commons image search when no API keys are set.
class ImageFetchService {
  static final ImageFetchService _instance = ImageFetchService._internal();
  factory ImageFetchService() => _instance;
  ImageFetchService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'DeepTutor/1.0 (Educational App; contact@deeptutor.app)',
    },
  ));

  // In-memory cache: query → image URL
  final Map<String, String> _cache = {};

  String? _googleApiKey;
  String? _googleCseId;

  /// Initialize from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _googleApiKey = prefs.getString('google_cse_api_key');
    _googleCseId = prefs.getString('google_cse_id');
  }

  /// Update API keys (called from settings)
  void updateKeys({String? apiKey, String? cseId}) {
    _googleApiKey = apiKey;
    _googleCseId = cseId;
  }

  bool get _isGoogleConfigured =>
      _googleApiKey != null &&
      _googleApiKey!.isNotEmpty &&
      _googleCseId != null &&
      _googleCseId!.isNotEmpty;

  /// Fetch image URL for a search query.
  /// Tries Google CSE first (if configured), then falls back to free sources.
  Future<String?> fetchImageUrl(String query) async {
    if (query.isEmpty) return null;

    // Check cache first
    if (_cache.containsKey(query)) return _cache[query];

    // Try Google Custom Search first if configured
    if (_isGoogleConfigured) {
      final googleUrl = await _fetchFromGoogle(query);
      if (googleUrl != null) return googleUrl;
    }

    // Free fallback: Wikimedia Commons
    final wikiUrl = await _fetchFromWikimedia(query);
    if (wikiUrl != null) return wikiUrl;

    // Free fallback 2: Wikipedia page thumbnail
    final wpUrl = await _fetchFromWikipedia(query);
    if (wpUrl != null) return wpUrl;

    return null;
  }

  /// Google Custom Search Images API
  Future<String?> _fetchFromGoogle(String query) async {
    try {
      final response = await _dio.get(
        'https://www.googleapis.com/customsearch/v1',
        queryParameters: {
          'key': _googleApiKey,
          'cx': _googleCseId,
          'q': query,
          'searchType': 'image',
          'num': 1,
          'imgSize': 'large',
          'safe': 'active',
        },
      );

      if (response.statusCode == 200) {
        final items = response.data['items'] as List?;
        if (items != null && items.isNotEmpty) {
          final imageUrl = items[0]['link']?.toString();
          if (imageUrl != null && imageUrl.isNotEmpty) {
            _cache[query] = imageUrl;
            return imageUrl;
          }
        }
      }
    } catch (e) {
      print('🖼️ Google CSE error: $e');
    }
    return null;
  }

  /// FREE: Wikimedia Commons image search (no API key needed)
  Future<String?> _fetchFromWikimedia(String query) async {
    try {
      final response = await _dio.get(
        'https://commons.wikimedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': '$query filetype:bitmap',
          'gsrnamespace': '6',
          'gsrlimit': '5',
          'prop': 'imageinfo',
          'iiprop': 'url|mime',
          'iiurlwidth': '800',
          'format': 'json',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final pages = data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          // Find the first valid image (skip SVG, prefer photos)
          for (final page in pages.values) {
            final imageInfo = (page['imageinfo'] as List?)?.first;
            if (imageInfo != null) {
              final mime = imageInfo['mime']?.toString() ?? '';
              // Skip SVGs and non-image types
              if (mime.contains('svg') || !mime.startsWith('image/')) continue;
              
              // Prefer the thumbnail URL (pre-sized) over the full original
              final thumbUrl = imageInfo['thumburl']?.toString();
              final fullUrl = imageInfo['url']?.toString();
              final url = thumbUrl ?? fullUrl;

              if (url != null && url.isNotEmpty) {
                _cache[query] = url;
                print('🖼️ Wikimedia found image for "$query"');
                return url;
              }
            }
          }
        }
      }
    } catch (e) {
      print('🖼️ Wikimedia error: $e');
    }
    return null;
  }

  /// FREE: Wikipedia page thumbnail (no API key needed)
  Future<String?> _fetchFromWikipedia(String query) async {
    try {
      // First search for a relevant page
      final searchResp = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'list': 'search',
          'srsearch': query,
          'srlimit': '3',
          'format': 'json',
        },
      );

      if (searchResp.statusCode == 200) {
        final results = searchResp.data['query']?['search'] as List?;
        if (results != null && results.isNotEmpty) {
          // Try each search result for a thumbnail
          for (final result in results) {
            final title = result['title']?.toString();
            if (title == null) continue;

            final imgResp = await _dio.get(
              'https://en.wikipedia.org/w/api.php',
              queryParameters: {
                'action': 'query',
                'titles': title,
                'prop': 'pageimages',
                'format': 'json',
                'pithumbsize': '800',
              },
            );

            if (imgResp.statusCode == 200) {
              final pages = imgResp.data['query']?['pages'] as Map<String, dynamic>?;
              if (pages != null) {
                for (final page in pages.values) {
                  final thumbUrl = page['thumbnail']?['source']?.toString();
                  if (thumbUrl != null && thumbUrl.isNotEmpty) {
                    _cache[query] = thumbUrl;
                    print('🖼️ Wikipedia found image for "$query" via "$title"');
                    return thumbUrl;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('🖼️ Wikipedia error: $e');
    }
    return null;
  }

  /// Process an entire AI response text:
  /// Finds all [FETCH_IMAGE: "query"] tags and replaces them with markdown image links.
  Future<String> processResponse(String text) async {
    // Matches [FETCH_IMAGE: keyword] or [FETCH_IMAGE: "keyword"]
    final pattern = RegExp(r'\[FETCH_IMAGE:\s*"?([^"\]]+)"?\]');
    final matches = pattern.allMatches(text).toList();

    if (matches.isEmpty) return text;

    String processed = text;
    // Process in reverse order to maintain string positions
    for (final match in matches.reversed) {
      final query = match.group(1)!;
      final imageUrl = await fetchImageUrl(query);

      if (imageUrl != null) {
        processed = processed.replaceRange(
          match.start,
          match.end,
          '![${_sanitizeAltText(query)}]($imageUrl)',
        );
      } else {
        // Keep as a styled placeholder (last resort)
        processed = processed.replaceRange(
          match.start,
          match.end,
          '\n> 🖼️ **Image:** _${_sanitizeAltText(query)}_\n',
        );
      }
    }

    return processed;
  }

  String _sanitizeAltText(String text) {
    return text.replaceAll('[', '').replaceAll(']', '').replaceAll('\n', ' ');
  }

  /// Clear the image cache
  void clearCache() => _cache.clear();
}
