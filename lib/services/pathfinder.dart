import 'dart:math';
import 'package:latlong2/latlong.dart';

/// A* pathfinding on a hardcoded waypoint graph of Cebu City streets.
class Pathfinder {
  // Waypoints around Cebu City
  static final List<LatLng> _waypoints = [
    const LatLng(10.2969, 123.9016), // 0  - Cebu City Hall
    const LatLng(10.2985, 123.9025), // 1
    const LatLng(10.3000, 123.9010), // 2
    const LatLng(10.3015, 123.9000), // 3
    const LatLng(10.3030, 123.9020), // 4
    const LatLng(10.3045, 123.9035), // 5
    const LatLng(10.3060, 123.9050), // 6
    const LatLng(10.3075, 123.9040), // 7
    const LatLng(10.3090, 123.9030), // 8
    const LatLng(10.3100, 123.9060), // 9
    const LatLng(10.3115, 123.9070), // 10
    const LatLng(10.3130, 123.9055), // 11
    const LatLng(10.3145, 123.9045), // 12
    const LatLng(10.3157, 123.8854), // 13 - SM Cebu / center
    const LatLng(10.3170, 123.8870), // 14
    const LatLng(10.3185, 123.8890), // 15
    const LatLng(10.3200, 123.8910), // 16
    const LatLng(10.3210, 123.8930), // 17
    const LatLng(10.3220, 123.8950), // 18
    const LatLng(10.3230, 123.8970), // 19
  ];

  // Adjacency list — each waypoint connects to nearby waypoints
  static final Map<int, List<int>> _edges = {
    0:  [1, 2],
    1:  [0, 2, 3],
    2:  [0, 1, 3, 4],
    3:  [1, 2, 4, 5],
    4:  [2, 3, 5, 6],
    5:  [3, 4, 6, 7],
    6:  [4, 5, 7, 8],
    7:  [5, 6, 8, 9],
    8:  [6, 7, 9, 10],
    9:  [7, 8, 10, 11],
    10: [8, 9, 11, 12],
    11: [9, 10, 12, 13],
    12: [10, 11, 13, 14],
    13: [11, 12, 14, 15],
    14: [12, 13, 15, 16],
    15: [13, 14, 16, 17],
    16: [14, 15, 17, 18],
    17: [15, 16, 18, 19],
    18: [16, 17, 19],
    19: [17, 18],
  };

  static double _haversine(LatLng a, LatLng b) {
    const R = 6371000.0; // Earth radius in metres
    final dLat = _toRad(b.latitude - a.latitude);
    final dLng = _toRad(b.longitude - a.longitude);
    final sinLat = sin(dLat / 2);
    final sinLng = sin(dLng / 2);
    final c = sinLat * sinLat +
        cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinLng * sinLng;
    return 2 * R * atan2(sqrt(c), sqrt(1 - c));
  }

  static double _toRad(double deg) => deg * pi / 180;

  /// Find the waypoint index nearest to [point]
  static int _nearest(LatLng point) {
    int best = 0;
    double bestDist = _haversine(point, _waypoints[0]);
    for (int i = 1; i < _waypoints.length; i++) {
      final d = _haversine(point, _waypoints[i]);
      if (d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  /// A* from [start] to [end] using the waypoint graph.
  /// Returns the full list of [LatLng] points along the path,
  /// including [start] and [end] as the first and last points.
  static List<LatLng> findPath(LatLng start, LatLng end) {
    final startIdx = _nearest(start);
    final endIdx = _nearest(end);

    if (startIdx == endIdx) return [start, end];

    // A* structures
    final openSet = <int>{startIdx};
    final cameFrom = <int, int>{};
    final gScore = <int, double>{for (var i = 0; i < _waypoints.length; i++) i: double.infinity};
    final fScore = <int, double>{for (var i = 0; i < _waypoints.length; i++) i: double.infinity};

    gScore[startIdx] = 0;
    fScore[startIdx] = _haversine(_waypoints[startIdx], _waypoints[endIdx]);

    while (openSet.isNotEmpty) {
      // Get node with lowest fScore
      final current = openSet.reduce(
          (a, b) => (fScore[a] ?? double.infinity) <= (fScore[b] ?? double.infinity) ? a : b);

      if (current == endIdx) {
        // Reconstruct path
        final path = <LatLng>[end];
        var node = current;
        while (cameFrom.containsKey(node)) {
          path.insert(0, _waypoints[node]);
          node = cameFrom[node]!;
        }
        path.insert(0, start);
        return path;
      }

      openSet.remove(current);

      for (final neighbor in (_edges[current] ?? [])) {
        final tentativeG = (gScore[current] ?? double.infinity) +
            _haversine(_waypoints[current], _waypoints[neighbor]);

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG +
              _haversine(_waypoints[neighbor], _waypoints[endIdx]);
          openSet.add(neighbor);
        }
      }
    }

    // Fallback: direct line
    return [start, end];
  }
}

