import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Generates a smooth rider path from [start] to [end].
/// Produces 200 interpolated steps with gentle road-like wobble.
/// Works for any two coordinates worldwide.
class Pathfinder {
  static const int _steps = 200;

  static List<LatLng> findPath(LatLng start, LatLng end) {
    final rng = Random(42); // fixed seed → deterministic path per order
    final path = <LatLng>[];

    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;

    // Max wobble ≈ 0.15% of straight-line distance, fades at ends
    final maxWobble = sqrt(dLat * dLat + dLng * dLng) * 0.0015;

    // Unit perpendicular vector (rotate 90°)
    final perpLat = -dLng;
    final perpLng = dLat;
    final perpLen = sqrt(perpLat * perpLat + perpLng * perpLng);
    final normPerpLat = perpLen > 0 ? perpLat / perpLen : 0.0;
    final normPerpLng = perpLen > 0 ? perpLng / perpLen : 0.0;

    double wobble = 0;
    for (int i = 0; i <= _steps; i++) {
      final t = i / _steps;
      // Bell-curve envelope — zero wobble at start/end
      final envelope = sin(t * pi);
      // Slow random drift
      wobble += (rng.nextDouble() - 0.5) * maxWobble * 0.3;
      wobble = wobble.clamp(-maxWobble, maxWobble);

      path.add(LatLng(
        start.latitude  + dLat * t + normPerpLat * wobble * envelope,
        start.longitude + dLng * t + normPerpLng * wobble * envelope,
      ));
    }
    return path;
  }
}
