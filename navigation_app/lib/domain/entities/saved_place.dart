import 'geo_point.dart';
import 'place.dart';

/// A small set of common labels the UI can offer as quick suggestions
/// (Home, Work, etc.) — the user can always type any custom label
/// instead, this is just for a nicer picker.
enum SavedPlaceIcon { home, work, university, restaurant, family, star, other }

/// A place the user has explicitly saved with their own label (product
/// spec "Сохранённые места"). Coordinates always come from a real,
/// already-resolved [Place] the user picked — this entity never carries
/// invented coordinates.
class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    required this.address,
    required this.location,
    this.icon = SavedPlaceIcon.other,
    required this.createdAt,
  });

  final String id;

  /// User-chosen name, e.g. "Дом", "Работа", "Любимый ресторан".
  final String label;
  final String address;
  final GeoPoint location;
  final SavedPlaceIcon icon;
  final DateTime createdAt;

  Place toPlace() => Place(
        id: 'saved_$id',
        name: label,
        address: address,
        location: location,
        category: PlaceCategory.other,
      );

  SavedPlace copyWith({
    String? label,
    String? address,
    GeoPoint? location,
    SavedPlaceIcon? icon,
  }) {
    return SavedPlace(
      id: id,
      label: label ?? this.label,
      address: address ?? this.address,
      location: location ?? this.location,
      icon: icon ?? this.icon,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'lat': location.latitude,
        'lng': location.longitude,
        'icon': icon.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
        id: json['id'] as String,
        label: json['label'] as String,
        address: json['address'] as String? ?? '',
        location: GeoPoint(
          latitude: (json['lat'] as num).toDouble(),
          longitude: (json['lng'] as num).toDouble(),
        ),
        icon: SavedPlaceIcon.values.firstWhere(
          (v) => v.name == json['icon'],
          orElse: () => SavedPlaceIcon.other,
        ),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
