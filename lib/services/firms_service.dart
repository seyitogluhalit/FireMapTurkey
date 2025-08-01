import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/fire_point.dart';

class FirmsService {
  static const String _apiKey = '995a772187152a20fab50fb135545809';
  static const String _baseUrl =
      'https://firms.modaps.eosdis.nasa.gov/api/area/csv';

  // Cache for API responses
  static final Map<String, List<FirePoint>> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};

  static Future<List<FirePoint>> fetchFires({
    String source = 'VIIRS_SNPP_NRT',
    int dayRange = 7,
    String area = '25,35,45,43',
  }) async {
    final cacheKey = '${source}_${dayRange}_$area';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheDuration) {
        return _cache[cacheKey]!;
      }
    }

    final url = Uri.parse('$_baseUrl/$_apiKey/$source/$area/$dayRange');

    try {
      final response = await http
          .get(
            url,
            headers: {'User-Agent': 'WildfireMapApp/1.0', 'Accept': 'text/csv'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return _cache[cacheKey] ?? [];
      }

      final lines = const LineSplitter().convert(response.body);
      if (lines.length < 2) {
        debugPrint('No data received from API');
        return [];
      }

      final List<FirePoint> firePoints = [];

      // Skip header and process data rows
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length < 14) continue;

        try {
          final firePoint = FirePoint.fromCsv(parts);
          if (firePoint.latitude != 0 && firePoint.longitude != 0) {
            firePoints.add(firePoint);
          }
        } catch (e) {
          debugPrint('Error parsing row $i: $e');
          continue;
        }
      }

      // Cache the result
      _cache[cacheKey] = firePoints;
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint('Fetched ${firePoints.length} fire points for $source');
      return firePoints;
    } catch (e) {
      debugPrint('Fetch error for $source: $e');
      // Return cached data if available, otherwise empty list
      return _cache[cacheKey] ?? [];
    }
  }

  // Clear cache when needed
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  // Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'cachedKeys': _cache.keys.toList(),
      'cacheSize': _cache.length,
      'timestamps': _cacheTimestamps,
    };
  }
}
