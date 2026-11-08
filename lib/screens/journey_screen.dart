import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../main.dart';
import '../models/journey.dart';
import '../models/place.dart';
import '../services/vehicle_service.dart';
import '../widgets/countdown.dart';
import '../widgets/mode_style.dart';

/// Full trip view: live map of the route and vehicles, plus every stop along the way.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({
    super.key,
    required this.journey,
    required this.origin,
    required this.destination,
  });
  final Journey journey;
  final Place origin;
  final Place destination;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  final _map = MapController();
  late Journey _journey = widget.journey;
  List<LiveVehicle> _vehicles = [];
  bool _showAllNearby = false;
  LatLng? _me;
  DateTime? _vehiclesUpdated;
  Timer? _vehicleTimer;
  Timer? _tripTimer;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _vehicleTimer = Timer.periodic(AppConfig.vehicleRefresh, (_) => _loadVehicles());
    _tripTimer = Timer.periodic(AppConfig.tripRefresh, (_) => _refreshTimes());
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 10),
    ).listen((p) => setState(() => _me = LatLng(p.latitude, p.longitude)), onError: (_) {});
  }

  @override
  void dispose() {
    _vehicleTimer?.cancel();
    _tripTimer?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  List<LatLng> get _allPoints => [
        for (final l in _journey.legs) ...l.path,
        for (final l in _journey.legs) ...l.stops.map((s) => s.coord).whereType<LatLng>(),
      ];

  Future<void> _loadVehicles() async {
    try {
      final rideLegs = _journey.legs.where((l) => !l.isWalk).toList();
      final v = _showAllNearby
          ? await vehicleService.vehiclesNear(rideLegs.map((l) => l.mode).toSet(), _allPoints)
          : await vehicleService.vehiclesForLegs(rideLegs);
      if (mounted) {
        setState(() {
          _vehicles = v;
          _vehiclesUpdated = DateTime.now();
        });
      }
    } catch (_) {}
  }

  /// Re-plan and pick up the same services so the countdowns use fresh estimates.
  Future<void> _refreshTimes() async {
    final key = _journey.firstRide;
    if (key == null) return;
    try {
      final fresh = await tfnswApi.planTrip(widget.origin, widget.destination,
          when: DateTime.now().subtract(const Duration(minutes: 2)));
      final match = fresh.where((j) {
        final r = j.firstRide;
        if (r == null) return false;
        if (key.realtimeTripId != null && r.realtimeTripId == key.realtimeTripId) return true;
        return r.routeNumber == key.routeNumber &&
            r.origin.departurePlanned == key.origin.departurePlanned;
      }).firstOrNull;
      if (match != null && mounted) {
        match.tags.addAll(_journey.tags);
        setState(() => _journey = match);
      }
    } catch (_) {}
  }

  void _focus(LatLng? p, {double zoom = 16}) {
    if (p != null) _map.move(p, zoom);
  }

  void _fitAll() {
    final pts = _allPoints;
    if (pts.length < 2) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 300),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pts = _allPoints;
    return Scaffold(
      appBar: AppBar(
        title: Text('To ${widget.destination.displayName}'),
        actions: [
          IconButton(tooltip: 'Show whole trip', icon: const Icon(Icons.zoom_out_map), onPressed: _fitAll),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: pts.isNotEmpty ? pts.first : const LatLng(-33.8688, 151.2093),
            initialZoom: 14,
            initialCameraFit: pts.length >= 2
                ? CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(pts),
                    padding: const EdgeInsets.fromLTRB(40, 40, 40, 300),
                  )
                : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'au.nswtransit.app',
            ),
            PolylineLayer(polylines: [
              for (final l in _journey.legs)
                if (l.path.length >= 2)
                  Polyline(
                    points: l.path,
                    color: ModeStyle.of(l.mode).color,
                    strokeWidth: l.isWalk ? 4 : 6,
                    pattern: l.isWalk ? const StrokePattern.dotted() : const StrokePattern.solid(),
                    borderColor: Colors.white,
                    borderStrokeWidth: l.isWalk ? 0 : 1.5,
                  ),
            ]),
            MarkerLayer(markers: [
              // every stop along each ride leg
              for (final l in _journey.legs.where((l) => !l.isWalk))
                for (final s in l.intermediateStops)
                  if (s.coord != null)
                    Marker(
                      point: s.coord!,
                      width: 12,
                      height: 12,
                      child: _StopDot(color: ModeStyle.of(l.mode).color, small: true),
                    ),
              // boarding / alighting points
              for (final l in _journey.legs.where((l) => !l.isWalk)) ...[
                if (l.origin.coord != null)
                  Marker(point: l.origin.coord!, width: 18, height: 18,
                      child: _StopDot(color: ModeStyle.of(l.mode).color)),
                if (l.destination.coord != null)
                  Marker(point: l.destination.coord!, width: 18, height: 18,
                      child: _StopDot(color: ModeStyle.of(l.mode).color)),
              ],
              Marker(
                point: widget.destination.latLng,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
              // live vehicles
              for (final v in _vehicles)
                Marker(
                  point: v.position,
                  width: 40,
                  height: 40,
                  child: _VehicleMarker(vehicle: v),
                ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                    ),
                  ),
                ),
            ]),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('OpenStreetMap contributors'), TextSourceAttribution('Transport for NSW')],
            ),
          ],
        ),
        // live-vehicle toggle
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(children: [
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.sensors,
                      size: 16, color: _vehicles.isEmpty ? Colors.grey : Colors.green.shade700),
                  const SizedBox(width: 6),
                  Text(_vehicles.isEmpty
                      ? 'No live vehicles yet'
                      : '${_vehicles.length} live · ${formatClock(_vehiclesUpdated)}'),
                ]),
              ),
            ),
            const Spacer(),
            FilterChip(
              elevation: 2,
              label: const Text('All nearby'),
              selected: _showAllNearby,
              onSelected: (v) {
                setState(() => _showAllNearby = v);
                _loadVehicles();
              },
            ),
          ]),
        ),
        if (_me != null)
          Positioned(
            right: 12,
            top: 64,
            child: FloatingActionButton.small(
              heroTag: 'me',
              onPressed: () => _focus(_me),
              child: const Icon(Icons.my_location),
            ),
          ),
        DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.15,
          maxChildSize: 0.92,
          builder: (context, scroll) => Material(
            elevation: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            color: Theme.of(context).colorScheme.surface,
            child: _Timeline(
              journey: _journey,
              scroll: scroll,
              destination: widget.destination,
              onFocus: _focus,
            ),
          ),
        ),
      ]),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot({required this.color, this.small = false});
  final Color color;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: small ? 2.5 : 4),
        ),
      );
}

class _VehicleMarker extends StatelessWidget {
  const _VehicleMarker({required this.vehicle});
  final LiveVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final s = ModeStyle.of(vehicle.mode);
    final age = vehicle.updated == null
        ? ''
        : ' · ${DateTime.now().difference(vehicle.updated!).inSeconds}s ago';
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: '${s.label} ${vehicle.label.isNotEmpty ? vehicle.label : vehicle.routeId}$age',
      child: Stack(alignment: Alignment.center, children: [
        if (vehicle.bearing != null)
          Transform.rotate(
            angle: vehicle.bearing! * math.pi / 180,
            child: Icon(Icons.navigation, size: 40, color: s.color.withValues(alpha: 0.35)),
          ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: s.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
          ),
          child: Icon(s.icon, size: 16, color: Colors.white),
        ),
      ]),
    );
  }
}

/// Step-by-step itinerary with every stop.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.journey,
    required this.scroll,
    required this.destination,
    required this.onFocus,
  });
  final Journey journey;
  final ScrollController scroll;
  final Place destination;
  final void Function(LatLng?, {double zoom}) onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Arrive ${formatClock(journey.arrival)}', style: theme.textTheme.titleLarge),
              Text(
                '${formatDuration(journey.totalDuration)} total · '
                '${journey.interchanges == 0 ? 'no changes' : '${journey.interchanges} change(s)'}',
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
          if (journey.firstRide != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Countdown(
                target: journey.firstRide!.origin.departure,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text('until it leaves', style: theme.textTheme.bodySmall),
            ]),
        ]),
        const Divider(height: 24),
        for (final leg in journey.legs)
          leg.isWalk ? _WalkTile(leg: leg, onFocus: onFocus) : _RideTile(leg: leg, onFocus: onFocus),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.flag, color: Colors.red),
          title: Text(destination.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Arrive ${formatClock(journey.arrival)}'),
          onTap: () => onFocus(destination.latLng),
        ),
      ],
    );
  }
}

class _WalkTile extends StatelessWidget {
  const _WalkTile({required this.leg, required this.onFocus});
  final Leg leg;
  final void Function(LatLng?, {double zoom}) onFocus;

  @override
  Widget build(BuildContext context) {
    if (leg.duration.inSeconds < 60 && leg.path.length < 2) return const SizedBox.shrink();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.directions_walk, color: Colors.grey),
      title: Text('Walk ${formatDuration(leg.duration)}'),
      subtitle: Text('to ${leg.destination.name}'),
      onTap: () => onFocus(leg.destination.coord),
    );
  }
}

class _RideTile extends StatelessWidget {
  const _RideTile({required this.leg, required this.onFocus});
  final Leg leg;
  final void Function(LatLng?, {double zoom}) onFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = ModeStyle.of(leg.mode);
    final stops = leg.intermediateStops;

    Widget stopRow(StopPoint p, {required bool major, String? prefix}) => InkWell(
          onTap: () => onFocus(p.coord),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: major ? 6 : 4),
            child: Row(children: [
              SizedBox(
                width: 40,
                child: Center(child: _StopDot(color: s.color, small: !major)),
              ),
              Expanded(
                child: Text(
                  prefix == null ? p.name : '$prefix ${p.name}',
                  style: major ? const TextStyle(fontWeight: FontWeight.w600) : theme.textTheme.bodyMedium,
                ),
              ),
              Text(formatClock(p.time),
                  style: TextStyle(
                    fontSize: 13,
                    color: p.isRealtime ? Colors.green.shade700 : null,
                    fontWeight: major ? FontWeight.w600 : null,
                  )),
            ]),
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: s.color, width: 4)),
      ),
      padding: const EdgeInsets.only(left: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(s.icon, size: 16, color: Colors.white),
              const SizedBox(width: 4),
              Text(leg.routeNumber.isEmpty ? s.label : leg.routeNumber,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('towards ${leg.headsign}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Countdown(
              target: leg.origin.departure,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            DelayBadge(delay: leg.origin.delay, realtime: leg.origin.isRealtime),
          ]),
        ]),
        if (leg.alerts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade800),
              const SizedBox(width: 4),
              Expanded(
                child: Text(leg.alerts.first,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade900)),
              ),
            ]),
          ),
        const SizedBox(height: 4),
        stopRow(leg.origin, major: true, prefix: 'Board at'),
        if (stops.isNotEmpty)
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.only(left: 40),
              childrenPadding: EdgeInsets.zero,
              dense: true,
              initiallyExpanded: stops.length <= 6,
              title: Text(
                '${stops.length} stop${stops.length == 1 ? '' : 's'} · ${formatDuration(leg.duration)}',
                style: theme.textTheme.bodySmall,
              ),
              children: [for (final st in stops) stopRow(st, major: false)],
            ),
          ),
        stopRow(leg.destination, major: true, prefix: 'Get off at'),
      ]),
    );
  }
}
