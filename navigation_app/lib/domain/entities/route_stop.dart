import 'place.dart';

/// A single stop within a multi-stop trip (product spec "Маршрут с
/// несколькими остановками"). Ordering matters — [RouteStop]s are kept
/// in a plain ordered list by whoever owns the trip (see
/// `MultiStopController`), and this entity carries no index of its own
/// so reordering (drag-and-drop) never requires renumbering anything.
class RouteStop {
  const RouteStop({required this.id, required this.place});

  /// Locally generated identifier (not the [Place.id]) so the exact same
  /// place can be added as two different stops without colliding.
  final String id;
  final Place place;
}
