import 'package:latlong2/latlong.dart';

/// Transport modes, mapped from TfNSW `product.class` values.
enum TransportMode { train, metro, lightRail, bus, coach, ferry, schoolBus, walk, other }

TransportMode modeFromClass(int? c) {
  switch (c) {
    case 1:
      return TransportMode.train;
    case 2:
      return TransportMode.metro;
    case 4:
      return TransportMode.lightRail;
    case 5:
      return TransportMode.bus;
    case 7:
      return TransportMode.coach;
    case 9:
      return TransportMode.ferry;
    case 11:
      return TransportMode.schoolBus;
    case 99:
    case 100:
      return TransportMode.walk;
    default:
      return TransportMode.other;
  }
}

DateTime? _time(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

LatLng? _coord(dynamic v) {
  if (v is List && v.length >= 2) {
    return LatLng((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }
  return null;
}

/// A stop (or the start/end point) on a leg.
class StopPoint {
  final String id;
  final String name;
  final LatLng? coord;
  final DateTime? arrivalPlanned;
  final DateTime? arrivalEstimated;
  final DateTime? departurePlanned;
  final DateTime? departureEstimated;

  StopPoint({
    required this.id,
    required this.name,
    this.coord,
    this.arrivalPlanned,
    this.arrivalEstimated,
    this.departurePlanned,
    this.departureEstimated,
  });

  DateTime? get departure => departureEstimated ?? departurePlanned;
  DateTime? get arrival => arrivalEstimated ?? arrivalPlanned;

  /// Best known time at this stop (departure if it has one, else arrival).
  DateTime? get time => departure ?? arrival;

  bool get isRealtime => departureEstimated != null || arrivalEstimated != null;

  /// Positive = running late, negative = early.
  Duration? get delay {
    final est = departureEstimated ?? arrivalEstimated;
    final plan = departurePlanned ?? arrivalPlanned;
    if (est == null || plan == null) return null;
    return est.difference(plan);
  }

  factory StopPoint.fromJson(Map<String, dynamic> j) {
    final parent = j['parent'] as Map<String, dynamic>?;
    return StopPoint(
      id: j['id'] as String? ?? '',
      name: (j['disassembledName'] as String?) ??
          (parent?['disassembledName'] as String?) ??
          (j['name'] as String? ?? ''),
      coord: _coord(j['coord']),
      arrivalPlanned: _time(j['arrivalTimePlanned']),
      arrivalEstimated: _time(j['arrivalTimeEstimated']),
      departurePlanned: _time(j['departureTimePlanned']),
      departureEstimated: _time(j['departureTimeEstimated']),
    );
  }
}

/// One leg of a journey: a walk, or a ride on a single service.
class Leg {
  final TransportMode mode;
  final String routeNumber; // e.g. "T1", "333", "F1"
  final String routeName; // e.g. "North Shore & Western Line"
  final String headsign; // service destination
  final StopPoint origin;
  final StopPoint destination;
  final List<StopPoint> stops; // every stop along the leg, in order
  final List<LatLng> path; // polyline
  final Duration duration;
  final String? realtimeTripId;
  final bool isCancelled;
  final List<String> alerts;

  Leg({
    required this.mode,
    required this.routeNumber,
    required this.routeName,
    required this.headsign,
    required this.origin,
    required this.destination,
    required this.stops,
    required this.path,
    required this.duration,
    this.realtimeTripId,
    this.isCancelled = false,
    this.alerts = const [],
  });

  bool get isWalk => mode == TransportMode.walk;

  /// Stops strictly between boarding and alighting.
  List<StopPoint> get intermediateStops =>
      stops.length > 2 ? stops.sublist(1, stops.length - 1) : const [];

  factory Leg.fromJson(Map<String, dynamic> j) {
    final t = (j['transportation'] as Map<String, dynamic>?) ?? {};
    final product = (t['product'] as Map<String, dynamic>?) ?? {};
    final props = (t['properties'] as Map<String, dynamic>?) ?? {};
    final dest = (t['destination'] as Map<String, dynamic>?) ?? {};

    final origin = StopPoint.fromJson(j['origin'] as Map<String, dynamic>);
    final destination = StopPoint.fromJson(j['destination'] as Map<String, dynamic>);

    final seq = (j['stopSequence'] as List?)
            ?.map((s) => StopPoint.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [origin, destination];

    var path = (j['coords'] as List?)?.map(_coord).whereType<LatLng>().toList() ?? [];
    if (path.isEmpty) {
      path = seq.map((s) => s.coord).whereType<LatLng>().toList();
    }

    final alerts = (j['infos'] as List?)
            ?.map((i) => (i as Map<String, dynamic>)['subtitle'] as String?)
            .whereType<String>()
            .toList() ??
        const <String>[];

    return Leg(
      mode: modeFromClass(product['class'] as int?),
      routeNumber: (t['disassembledName'] as String?) ?? (t['number'] as String? ?? ''),
      routeName: (t['description'] as String?) ?? (product['name'] as String? ?? ''),
      headsign: dest['name'] as String? ?? '',
      origin: origin,
      destination: destination,
      stops: seq,
      path: path,
      duration: Duration(seconds: (j['duration'] as num?)?.toInt() ?? 0),
      realtimeTripId: props['RealtimeTripId'] as String?,
      isCancelled: j['isCancelled'] == true || props['isCancelled'] == true,
      alerts: alerts,
    );
  }
}

/// A complete door-to-door option.
class Journey {
  final List<Leg> legs;
  final Set<String> tags = {}; // "Fastest", "Fewest changes", "Least walking"

  Journey(this.legs);

  Leg? get firstRide => legs.where((l) => !l.isWalk).firstOrNull;

  DateTime get departure => legs.first.origin.departure ?? DateTime.now();
  DateTime get arrival => legs.last.destination.arrival ?? departure.add(totalDuration);

  Duration get totalDuration => arrival.difference(departure);

  int get interchanges => (legs.where((l) => !l.isWalk).length - 1).clamp(0, 99);

  Duration get walkingTime =>
      legs.where((l) => l.isWalk).fold(Duration.zero, (a, l) => a + l.duration);

  /// When the first vehicle leaves (what the user is racing to catch).
  DateTime? get firstServiceDeparture => firstRide?.origin.departure;

  factory Journey.fromJson(Map<String, dynamic> j) => Journey(
        (j['legs'] as List).map((l) => Leg.fromJson(l as Map<String, dynamic>)).toList(),
      );
}
