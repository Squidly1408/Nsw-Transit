import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/journey.dart';
import '../models/place.dart';

class TfnswException implements Exception {
  final String message;
  TfnswException(this.message);
  @override
  String toString() => message;
}

/// Client for the Transport for NSW Trip Planner API.
class TfnswApi {
  TfnswApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _tpVersion = '10.2.1.42';

  Map<String, String> get _headers {
    if (AppConfig.apiKey.isEmpty) {
      throw TfnswException(
          'No API key set. Run with --dart-define=TFNSW_API_KEY=your_key');
    }
    return {'Authorization': 'apikey ${AppConfig.apiKey}'};
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, String> params) async {
    final uri = Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: params);
    final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TfnswException('API key rejected (${res.statusCode}). Check your TfNSW key.');
    }
    if (res.statusCode != 200) {
      throw TfnswException('Transport NSW returned ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Search stops, addresses and points of interest across NSW.
  Future<List<Place>> searchPlaces(String query) async {
    if (query.trim().length < 2) return [];
    final data = await _getJson('/v1/tp/stop_finder', {
      'outputFormat': 'rapidJSON',
      'type_sf': 'any',
      'name_sf': query.trim(),
      'coordOutputFormat': 'EPSG:4326',
      'TfNSWSF': 'true',
      'version': _tpVersion,
    });
    final locs = (data['locations'] as List?) ?? [];
    locs.sort((a, b) => ((b['matchQuality'] ?? 0) as num).compareTo((a['matchQuality'] ?? 0) as num));
    return locs
        .map((l) => Place.fromStopFinder(l as Map<String, dynamic>))
        .whereType<Place>()
        .take(15)
        .toList();
  }

  /// Plan trips from [from] to [to], leaving at [when] (default now).
  /// Returns journeys ranked quickest-first and tagged with their strengths.
  Future<List<Journey>> planTrip(Place from, Place to, {DateTime? when}) async {
    final t = when ?? DateTime.now();
    final data = await _getJson('/v1/tp/trip', {
      'outputFormat': 'rapidJSON',
      'coordOutputFormat': 'EPSG:4326',
      'depArrMacro': 'dep',
      'itdDate': DateFormat('yyyyMMdd').format(t),
      'itdTime': DateFormat('HHmm').format(t),
      'type_origin': from.tripPlannerType,
      'name_origin': from.tripPlannerName,
      'type_destination': to.tripPlannerType,
      'name_destination': to.tripPlannerName,
      'calcNumberOfTrips': '6',
      'TfNSWTR': 'true',
      'version': _tpVersion,
    });

    final raw = (data['journeys'] as List?) ?? [];
    if (raw.isEmpty) {
      final msg = (data['systemMessages'] as List?)
          ?.map((m) => (m as Map)['text'])
          .whereType<String>()
          .firstOrNull;
      throw TfnswException(msg ?? 'No trips found between these places.');
    }

    final journeys = raw
        .map((j) => Journey.fromJson(j as Map<String, dynamic>))
        .where((j) => !j.legs.any((l) => l.isCancelled))
        // drop options whose first service has already gone
        .where((j) =>
            j.firstServiceDeparture == null ||
            j.firstServiceDeparture!.isAfter(DateTime.now().subtract(const Duration(minutes: 1))))
        .toList();

    return rankJourneys(journeys);
  }

  /// Quickest arrival first; ties broken by fewer changes then less walking.
  static List<Journey> rankJourneys(List<Journey> list) {
    if (list.isEmpty) return list;
    list.sort((a, b) {
      final c = a.arrival.compareTo(b.arrival);
      if (c != 0) return c;
      final i = a.interchanges.compareTo(b.interchanges);
      if (i != 0) return i;
      return a.walkingTime.compareTo(b.walkingTime);
    });
    list.first.tags.add('Fastest');

    final fewest = list.map((j) => j.interchanges).reduce((a, b) => a < b ? a : b);
    list.firstWhere((j) => j.interchanges == fewest).tags.add('Fewest changes');

    final leastWalk = list.reduce((a, b) => a.walkingTime <= b.walkingTime ? a : b);
    leastWalk.tags.add('Least walking');
    return list;
  }
}
