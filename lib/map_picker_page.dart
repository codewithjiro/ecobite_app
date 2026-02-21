import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'constants.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pickedLocation;
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Pin Your Location'),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.9)
            : CupertinoColors.white.withValues(alpha: 0.9),
        trailing: _pickedLocation != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context, _pickedLocation),
                child: const Text('Confirm',
                    style: TextStyle(
                        color: kPrimary, fontWeight: FontWeight.bold)),
              )
            : null,
      ),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  const LatLng(kMapCenterLat, kMapCenterLng),
              initialZoom: 14,
              onTap: (tapPosition, point) {
                setState(() => _pickedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.lamonco.lamon_go',
              ),
              if (_pickedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pickedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        CupertinoIcons.location_fill,
                        color: CupertinoColors.systemRed,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          // Hint banner
          if (_pickedLocation == null)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          CupertinoColors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.hand_point_left_fill,
                        color: kPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tap anywhere on the map to pin your delivery location',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? kDarkCard : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          CupertinoColors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.location_fill,
                        color: CupertinoColors.systemRed),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Lat: ${_pickedLocation!.latitude.toStringAsFixed(5)}\nLng: ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? CupertinoColors.white
                              : CupertinoColors.black,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          Navigator.pop(context, _pickedLocation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                              color: CupertinoColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

