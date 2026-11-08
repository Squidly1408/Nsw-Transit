import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../main.dart';
import '../models/journey.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../widgets/countdown.dart';
import '../widgets/leg_chips.dart';
import '../widgets/mode_style.dart';
import 'home_screen.dart';
import 'journey_screen.dart';
import 'search_screen.dart';

/// Lists trip options from the user's location (or chosen origin) to [destination],
/// quickest first, with live countdowns. Auto-refreshes.
class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key, required this.destination, this.origin});
  final Place destination;
  final Place? origin;

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  Place? _origin;
  late Place _destination;
  List<Journey> _journeys = [];
  bool _loading = true;
  String? _error;
  DateTime? _updated;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    _origin = widget.origin;
    _load();
    _refresh = Timer.periodic(AppConfig.tripRefresh, (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      _origin ??= await LocationService.currentPlace();
      final j = await tfnswApi.planTrip(_origin!, _destination);
      if (!mounted) return;
      setState(() {
        _journeys = j;
        _error = null;
        _updated = DateTime.now();
      });
    } catch (e) {
      if (mounted && !silent) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeOrigin() async {
    final p = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
          builder: (_) => const SearchScreen(title: 'Starting from…', allowCurrentLocation: true)),
    );
    if (p != null) {
      _origin = p;
      _load();
    }
  }

  void _swap() {
    if (_origin == null) return;
    final o = _origin!;
    setState(() {
      _origin = _destination;
      _destination = o;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_destination.displayName),
        actions: [
          ListenableBuilder(
            listenable: favouritesStore,
            builder: (_, __) {
              final fav = favouritesStore.isFavourite(_destination);
              return IconButton(
                tooltip: fav ? 'Saved' : 'Save as favourite',
                icon: Icon(fav ? Icons.star : Icons.star_border),
                onPressed: fav
                    ? null
                    : () async {
                        final e = await showFavouriteEditor(context, _destination);
                        if (e != null) favouritesStore.addFavourite(e);
                      },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Column(children: [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.trip_origin, color: Colors.green),
                  title: Text(_origin?.displayName ?? 'Finding your location…'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: _changeOrigin,
                ),
                Row(children: [
                  const SizedBox(width: 16),
                  const Expanded(child: Divider()),
                  IconButton(icon: const Icon(Icons.swap_vert), onPressed: _swap, tooltip: 'Swap'),
                ]),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.place, color: Colors.red),
                  title: Text(_destination.displayName),
                  subtitle: _destination.label?.isNotEmpty == true ? Text(_destination.name) : null,
                ),
              ]),
            ),
            if (_updated != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Text('Live · updated ${formatClock(_updated)} · refreshes every 30s',
                    style: theme.textTheme.bodySmall),
              ),
            if (_loading && _journeys.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(_error!),
                  trailing: TextButton(onPressed: _load, child: const Text('Retry')),
                ),
              ),
            for (final j in _journeys)
              JourneyCard(
                journey: j,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => JourneyScreen(
                      journey: j,
                      origin: _origin!,
                      destination: _destination,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One trip option.
class JourneyCard extends StatelessWidget {
  const JourneyCard({super.key, required this.journey, required this.onTap});
  final Journey journey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = journey.firstRide;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (journey.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(spacing: 6, children: [
                  for (final t in journey.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: t == 'Fastest'
                            ? Colors.green.shade100
                            : theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t == 'Fastest' ? Colors.green.shade900 : null)),
                    ),
                ]),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${formatClock(journey.departure)} – ${formatClock(journey.arrival)}',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDuration(journey.totalDuration)}'
                    ' · ${journey.interchanges == 0 ? 'Direct' : '${journey.interchanges} change${journey.interchanges > 1 ? 's' : ''}'}'
                    ' · ${formatDuration(journey.walkingTime)} walk',
                    style: theme.textTheme.bodySmall,
                  ),
                ]),
              ),
              if (first != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Countdown(
                    target: first.origin.departure,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text('${ModeStyle.of(first.mode).label} ${first.routeNumber} leaves',
                      style: theme.textTheme.bodySmall),
                ]),
            ]),
            const SizedBox(height: 10),
            LegChips(legs: journey.legs),
            if (first != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text('From ${first.origin.name}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ),
                DelayBadge(delay: first.origin.delay, realtime: first.origin.isRealtime),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
