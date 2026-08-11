/// A typed failure surfaced to the UI layer.
///
/// Every failure carries a [message] that is safe and friendly to show
/// directly to the user (never a raw exception or stack trace — see
/// requirement 56 in the product spec). The optional [technicalDetail] is
/// for logging only and must never be rendered in the UI.
sealed class AppFailure {
  const AppFailure(this.message, {this.technicalDetail});

  final String message;
  final String? technicalDetail;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure({String? technicalDetail})
      : super(
          "Couldn't connect. Check your internet connection and try again.",
          technicalDetail: technicalDetail,
        );
}

class LocationPermissionFailure extends AppFailure {
  const LocationPermissionFailure({String? technicalDetail})
      : super(
          'Location access is needed to show your position on the map.',
          technicalDetail: technicalDetail,
        );
}

class LocationUnavailableFailure extends AppFailure {
  const LocationUnavailableFailure({String? technicalDetail})
      : super(
          "We couldn't determine your location right now.",
          technicalDetail: technicalDetail,
        );
}

class GeocodingFailure extends AppFailure {
  const GeocodingFailure({String? technicalDetail})
      : super(
          "We couldn't find that place. Try a different search.",
          technicalDetail: technicalDetail,
        );
}

class RoutingFailure extends AppFailure {
  const RoutingFailure({String? technicalDetail})
      : super(
          "We couldn't calculate a route there right now.",
          technicalDetail: technicalDetail,
        );
}

class TrafficFailure extends AppFailure {
  const TrafficFailure({String? technicalDetail})
      : super(
          'Traffic data is temporarily unavailable.',
          technicalDetail: technicalDetail,
        );
}

class ParkingFailure extends AppFailure {
  const ParkingFailure({String? technicalDetail})
      : super(
          "We couldn't find parking nearby right now.",
          technicalDetail: technicalDetail,
        );
}

class AiNavigationFailure extends AppFailure {
  const AiNavigationFailure({String? technicalDetail})
      : super(
          "The assistant couldn't process that. Try rephrasing your request.",
          technicalDetail: technicalDetail,
        );
}

class VoiceFailure extends AppFailure {
  const VoiceFailure({String? technicalDetail})
      : super(
          "We couldn't hear that clearly. Please try again.",
          technicalDetail: technicalDetail,
        );
}

class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure({String? technicalDetail})
      : super(
          'This feature is not available right now.',
          technicalDetail: technicalDetail,
        );
}

class UnknownFailure extends AppFailure {
  const UnknownFailure({String? technicalDetail})
      : super(
          'Something went wrong. Please try again.',
          technicalDetail: technicalDetail,
        );
}
