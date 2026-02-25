import 'dart:convert';

class SavedAddress {
  final String id;
  final String label;
  final double lat;
  final double lng;
  final bool isDefault;

  SavedAddress({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
        'isDefault': isDefault,
      };

  factory SavedAddress.fromMap(Map<String, dynamic> map) => SavedAddress(
        id: map['id'] as String,
        label: map['label'] as String,
        lat: (map['lat'] as num).toDouble(),
        lng: (map['lng'] as num).toDouble(),
        isDefault: map['isDefault'] as bool? ?? false,
      );

  // ── Hive helpers ──────────────────────────────────────────────────────────
  static List<SavedAddress> loadAll() {
    // Imported by callers — kept static so no Hive import needed here
    // Callers pass the raw JSON string from Hive
    return [];
  }

  static List<SavedAddress> decodeList(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      return list
          .map((e) => SavedAddress.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String encodeList(List<SavedAddress> addresses) =>
      jsonEncode(addresses.map((a) => a.toMap()).toList());

  String get coordString =>
      '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

