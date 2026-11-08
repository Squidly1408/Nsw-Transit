import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../widgets/mode_style.dart';

/// Search for any NSW address, stop, station, wharf or landmark.
/// Pops with the chosen [Place].
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.title, this.allowCurrentLocation = false});
  final String title;
  final bool allowCurrentLocation;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  Future<void> _run(String q) async {
    final id = ++_requestId;
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await tfnswApi.searchPlaces(q);
      if (id == _requestId && mounted) setState(() => _results = r);
    } catch (e) {
      if (id == _requestId && mounted) setState(() => _error = e.toString());
    } finally {
      if (id == _requestId && mounted) setState(() => _loading = false);
    }
  }

  IconData _iconFor(Place p) {
    switch (p.type) {
      case 'stop':
      case 'platform':
        return Icons.departure_board;
      case 'poi':
        return Icons.place;
      case 'locality':
      case 'suburb':
        return Icons.location_city;
      default:
        return Icons.home_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final favs = favouritesStore.favourites;
    final showSuggestions = _ctrl.text.trim().length < 2;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: _run,
          decoration: InputDecoration(
            hintText: widget.title,
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _results = []);
                    }),
          ),
        ),
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator())
            : null,
      ),
      body: ListView(children: [
        if (_error != null)
          ListTile(leading: const Icon(Icons.error_outline, color: Colors.red), title: Text(_error!)),
        if (showSuggestions && widget.allowCurrentLocation)
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('My current location'),
            onTap: () async {
              try {
                final p = await LocationService.currentPlace();
                if (context.mounted) Navigator.pop(context, p);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          ),
        if (showSuggestions)
          for (final f in favs)
            ListTile(
              leading: Icon(favouriteIcon(f.icon)),
              title: Text(f.displayName),
              subtitle: Text(f.name, maxLines: 1),
              onTap: () => Navigator.pop(context, f),
            ),
        for (final p in _results)
          ListTile(
            leading: Icon(_iconFor(p)),
            title: Text(p.name),
            subtitle: p.subtitle == null ? null : Text(p.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.pop(context, p),
          ),
        if (!showSuggestions && !_loading && _results.isEmpty && _error == null)
          const ListTile(title: Text('No matches. Try a street address, suburb or stop name.')),
      ]),
    );
  }
}
