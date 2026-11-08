import 'package:gtfs_realtime_bindings/gtfs_realtime_bindings.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/journey.dart';

/// A live vehicle position from the GTFS-realtime feeds.
class LiveVehicle {
  final String id;
  final String tripId;
  final String routeId;
  final String label;
  final LatLng position;
  final double? bearing;
  final TransportMode mode;
  final DateTime? updated;

  LiveVehicle({
    required this.id,
    required this.tripId,
    required this.routeId,
    required this.label,
    required this.position,
    required this.mode,
    this.bearing,
    this.updated,
  });
}

/// Fetches live vehicle positions for buses, trains, metro and ferries.
class VehicleService {
  VehicleService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  /// GTFS-realtime vehicle position feeds per mode.
  /// Sydney Trains and Metro are on v2; buses and ferries on v1.
  static const Map<TransportMode, List<String>> feeds = {
    TransportMode.bus: ['/v1/gtfs/vehiclepos/buses'],
    TransportMode.schoolBus: ['/v1/gtfs/vehiclepos/buses'],
    TransportMode.train: ['/v2/gtfs/vehiclepos/sydneytrains', '/v1/gtfs/vehiclepos/nswtrains'],
    TransportMode.metro: ['/v2/gtfs/vehiclepos/metro'],
    TransportMode.ferry: ['/v1/gtfs/vehiclepos/ferries/sydneyferries'],
    TransportMode.lightRail: ['/v2/gtfs/vehiclepos/lightrail/innerwest', '/v1/gtfs/vehiclepos/lightrail/cbdandsoutheast'],
    TransportMode.coach: ['/v1/gtfs/vehiclepos/regionbuses'],
  };

  final Map<String, (DateTime, List<LiveVehicle>)> _cache = {};

  Future<List<LiveVehicle>> _fetchFeed(String path, TransportMode mode) async {
    final cached = _cache[path];
    if (cached != null && DateTime.now().difference(cached.$1) < const Duration(seconds: 10)) {
      return cached.$2;
    }
    final res = await _client.get(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'apikey ${AppConfig.apiKey}',
        'Accept': 'application/x-google-protobuf',
      },
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return cached?.$2 ?? [];

    final feed = FeedMessage.fromBuffer(res.bodyBytes);
    final out = <LiveVehicle>[];
    for (final e in feed.entity) {
      if (!e.hasVehicle() || !e.vehicle.hasPosition()) continue;
      final v = e.vehicle;
      out.add(LiveVehicle(
        id: v.vehicle.id.isNotEmpty ? v.vehicle.id : e.id,
        tripId: v.trip.tripId,
        routeId: v.trip.routeId,
        label: v.vehicle.label,
        position: LatLng(v.position.latitude, v.position.longitude),
        bearing: v.position.hasBearing() ? v.position.bearing : null,
        mode: mode,
        updated: v.hasTimestamp()
            ? DateTime.fromMillisecondsSinceEpoch(v.timestamp.toInt() * 1000)
            : null,
      ));
    }
    _cache[path] = (DateTime.now(), out);
    return out;
  }

  /// Live vehicles relevant to the given legs.
  ///
  /// Prefers an exact trip match (the vehicle actually running your service).
  /// If the operator doesn't publish a matching trip id, falls back to vehicles
  /// on the same route near the leg so you still see what's coming.
  Future<List<LiveVehicle>> vehiclesForLegs(List<Leg> legs) async {
    final results = <String, LiveVehicle>{};
    for (final leg in legs.where((l) => !l.isWalk)) {
      final paths = feeds[leg.mode];
      if (paths == null) continue;
      for (final p in paths) {
        List<LiveVehicle> all;
        try {
          all = await _fetchFeed(p, leg.mode);
        } catch (_) {
          continue;
        }
        final exact = leg.realtimeTripId == null
            ? <LiveVehicle>[]
            : all.where((v) => v.tripId == leg.realtimeTripId).toList();
        if (exact.isNotEmpty) {
          for (final v in exact) {
            results[v.id] = v;
          }
          break;
        }
        // Fallback: same route number, within the leg's area (+~3km).
        final route = leg.routeNumber.toLowerCase();
        if (route.isEmpty || leg.path.isEmpty) continue;
        final bounds = _bounds(leg.path, padDeg: 0.03);
        for (final v in all) {
          final rid = v.routeId.toLowerCase();
          final sameRoute = rid == route || rid.endsWith('_$route') || rid.startsWith('$route-') ||
              rid.contains('_${route}_');
          if (sameRoute && _inBounds(v.position, bounds)) results[v.id] = v;
        }
      }
    }
    return results.values.toList();
  }

  /// Every live vehicle of the given modes within the area covered by [area].
  Future<List<LiveVehicle>> vehiclesNear(Set<TransportMode> modes, List<LatLng> area) async {
    if (area.isEmpty) return [];
    final b = _bounds(area, padDeg: 0.01);
    final paths = <String, TransportMode>{};
    for (final m in modes) {
      for (final p in feeds[m] ?? const <String>[]) {
        paths[p] = m;
      }
    }
    final out = <String, LiveVehicle>{};
    for (final e in paths.entries) {
      try {
        for (final v in await _fetchFeed(e.key, e.value)) {
          if (_inBounds(v.position, b)) out[v.id] = v;
        }
      } catch (_) {}
    }
    return out.values.toList();
  }

  static (double, double, double, double) _bounds(List<LatLng> pts, {double padDeg = 0}) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return (minLat - padDeg, maxLat + padDeg, minLng - padDeg, maxLng + padDeg);
  }

  static bool _inBounds(LatLng p, (double, double, double, double) b) =>
      p.latitude >= b.$1 && p.latitude <= b.$2 && p.longitude >= b.$3 && p.longitude <= b.$4;
}
