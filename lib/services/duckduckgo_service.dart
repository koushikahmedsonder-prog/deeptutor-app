import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class DuckDuckGoService {
  static final Dio _dio = Dio();

  static Future<String> search(String query) async {
    try {
      // Native Windows ignores CORS, so we can directly query DuckDuckGo HTML API natively!
      final url = 'https://html.duckduckgo.com/html/?q=${Uri.encodeComponent(query)}';
      
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final htmlStr = response.data.toString();
      final results = _parseHtml(htmlStr);
      print('🦆 DuckDuckGo Found ${results.split('\n').length - 1} results');
      return results;
    } catch (e) {
      print('🦆 DuckDuckGo search error: $e');
      return '';
    }
  }

  static String _parseHtml(String html) {
    final results = <String>[];
    
    final regex = RegExp(r'<a[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)<\/a>', dotAll: true);
    final titleRegex = RegExp(r'<h2 class="result__title">.*?<a[^>]*>(.*?)<\/a>.*?<\/h2>', dotAll: true);
    final urlRegex = RegExp(r'<a class="result__url" href="([^"]+)">', dotAll: true);
    
    final snippetMatches = regex.allMatches(html).toList();
    final titleMatches = titleRegex.allMatches(html).toList();
    final urlMatches = urlRegex.allMatches(html).toList();

    for (int i = 0; i < snippetMatches.length && i < 10; i++) {
       final snippet = _stripHtml(snippetMatches[i].group(1) ?? '');
       final title = i < titleMatches.length ? _stripHtml(titleMatches[i].group(1) ?? '') : 'Result ${i+1}';
       final urlStr = i < urlMatches.length ? _extractUrl(urlMatches[i].group(1) ?? '') : '';
       
       if (snippet.isNotEmpty) {
         results.add('- **$title**: $snippet (Source: $urlStr)');
       }
    }
    
    if (results.isEmpty) return '';
    
    return 'WEB SEARCH RESULTS (Use these to answer the user accurately, include the Source URL if helpful):\n${results.join('\n')}\n---\n';
  }

  static String _extractUrl(String urlFragment) {
     if (urlFragment.startsWith('//duckduckgo.com/l/?uddg=')) {
         final encoded = urlFragment.replaceAll('//duckduckgo.com/l/?uddg=', '').split('&').first;
         return Uri.decodeComponent(encoded);
     }
     return urlFragment;
  }

  static String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&#039;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<String> fetchPageContent(String url) async {
    try {
      // 1. Direct PDF Download
      if (url.toLowerCase().endsWith('.pdf') || url.toLowerCase().contains('.pdf?')) {
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
        return _extractPdfText(Uint8List.fromList(response.data!));
      }

      // 2. Normal HTML Fetch
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      final html = response.data.toString();
      
      // AUTO-DISCOVER FIRST PDF ON PAGE 
      String extraPdfContent = '';
      final pdfRegex = RegExp(r'href="([^"]+\.pdf(?:[^"]*))"', caseSensitive: false);
      final pdfMatch = pdfRegex.firstMatch(html);
      if (pdfMatch != null) {
        String pdfUrl = pdfMatch.group(1)!;
        if (!pdfUrl.startsWith('http')) {
           pdfUrl = Uri.parse(url).resolve(pdfUrl).toString();
        }
        try {
          final pdfResponse = await _dio.get<List<int>>(
            pdfUrl,
            options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 8)),
          );
          extraPdfContent = '\n[FOUND PDF ON PAGE: $pdfUrl]\n${_extractPdfText(Uint8List.fromList(pdfResponse.data!))}';
        } catch (_) {}
      }

      // Extract paragraphs only
      final paraRegex = RegExp(r'<p[^>]*>(.*?)<\/p>', dotAll: true);
      final paras = paraRegex.allMatches(html)
          .map((m) => _stripHtml(m.group(1) ?? ''))
          .where((t) => t.length > 80) // skip nav/footer junk
          .take(6) // top 6 paragraphs
          .join('\n');
      return paras + (extraPdfContent.isNotEmpty ? '\n\n$extraPdfContent' : '');
    } catch (e) {
      print('🦆 Content fetch error for $url: $e');
      return '';
    }
  }

  static String _extractPdfText(Uint8List pdfBytes) {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      final text = extractor.extractText();
      document.dispose();
      
      if (text.trim().isEmpty) return '[PDF: Image-only or empty]';
      return text.length > 5000 ? '${text.substring(0, 5000)}\n...[PDF truncated]' : text;
    } catch (e) {
      return '[Could not parse PDF]';
    }
  }

  static Future<String> searchWithContent(String query) async {
    final snippets = await search(query);
    
    // Also fetch content from top 3 URLs
    final urlRegex = RegExp(r'Source: (https?://[^\)]+)');
    final urls = urlRegex.allMatches(snippets).take(3).toList();
    
    final contents = <String>[];
    for (final match in urls) {
      final content = await fetchPageContent(match.group(1)!);
      if (content.isNotEmpty) {
        contents.add('**Source:** ${match.group(1)}\n$content');
      }
    }
    
    return '$snippets\n\nFULL PAGE CONTENT:\n${contents.join('\n---\n')}';
  }
}
