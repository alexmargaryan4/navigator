import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin helper for persisting a `List<Map<String, dynamic>>` under one
/// [SharedPreferences] string key, JSON-encoded.
///
/// This app has no backend (see README "Scope") — every "saved" feature
/// (saved places, favorite routes, trip history) is real local
/// persistence via this helper, not an in-memory placeholder. Kept as
/// one small shared utility rather than three copy-pasted
/// read/decode/write implementations.
class LocalJsonStore {
  const LocalJsonStore(this._key);

  final String _key;

  Future<List<Map<String, dynamic>>> readList() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      // Corrupt/legacy data on disk — treat as empty rather than
      // crashing the whole feature.
      return [];
    }
  }

  Future<void> writeList(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
  }
}
