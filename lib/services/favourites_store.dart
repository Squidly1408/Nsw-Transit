import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/place.dart';

/// Persists favourite and recent places on the device.
class FavouritesStore extends ChangeNotifier {
  static const _favKey = 'favourites_v1';
  static const _recentKey = 'recents_v1';
  static const _maxRecents = 8;

  List<Place> _favourites = [];
  List<Place> _recents = [];

  List<Place> get favourites => List.unmodifiable(_favourites);
  List<Place> get recents => List.unmodifiable(_recents);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _favourites = _decode(prefs.getString(_favKey));
    _recents = _decode(prefs.getString(_recentKey));
    notifyListeners();
  }

  List<Place> _decode(String? s) {
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List)
          .map((e) => Place.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favKey, jsonEncode(_favourites.map((p) => p.toJson()).toList()));
    await prefs.setString(_recentKey, jsonEncode(_recents.map((p) => p.toJson()).toList()));
    notifyListeners();
  }

  bool isFavourite(Place p) => _favourites.any((f) => f.id == p.id);

  Future<void> addFavourite(Place p) async {
    _favourites.removeWhere((f) => f.id == p.id);
    _favourites.add(p);
    await _save();
  }

  Future<void> updateFavourite(Place p) async {
    final i = _favourites.indexWhere((f) => f.id == p.id);
    if (i >= 0) _favourites[i] = p;
    await _save();
  }

  Future<void> removeFavourite(Place p) async {
    _favourites.removeWhere((f) => f.id == p.id);
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final p = _favourites.removeAt(oldIndex);
    _favourites.insert(newIndex, p);
    await _save();
  }

  Future<void> addRecent(Place p) async {
    _recents.removeWhere((r) => r.id == p.id);
    _recents.insert(0, p);
    if (_recents.length > _maxRecents) _recents = _recents.sublist(0, _maxRecents);
    await _save();
  }

  Future<void> clearRecents() async {
    _recents.clear();
    await _save();
  }
}
