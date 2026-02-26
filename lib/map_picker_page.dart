import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'constants.dart';

// ── Nominatim result model ────────────────────────────────────────────────────
class _Place {
  final String displayName;
  final LatLng location;
  const _Place({required this.displayName, required this.location});
}

// ── Return value from MapPickerPage ──────────────────────────────────────────
class MapPickerResult {
  final LatLng location;
  final String? address;
  const MapPickerResult({required this.location, this.address});
}

class MapPickerPage extends StatefulWidget {
  final String? hint;
  final LatLng? initialLocation;
  const MapPickerPage({super.key, this.hint, this.initialLocation});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? _pickedLocation;
  String? _pickedAddress;
  bool _loadingAddress = false;

  final MapController _mapController = MapController();

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<_Place> _suggestions = [];
  bool _searching = false;
  bool _searchError = false;
  Timer? _debounce;
  bool _showSuggestions = false;

  static const _nominatimHeaders = {
    'User-Agent': 'LamonGoApp/1.0 (ecobite.app@gmail.com)',
    'Accept-Language': 'en',
  };

  // GPS
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _pickedLocation = widget.initialLocation;
      _reverseGeocode(widget.initialLocation!);
    }
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        // Small delay so a suggestion tap can fire before the list disappears
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showSuggestions = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Search ──────────────────────────────────────────────────────────────────
  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500),
        () => _fetchSuggestions(query.trim()));
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() { _searching = true; _searchError = false; });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&addressdetails=1',
      );
      final res = await http.get(uri, headers: _nominatimHeaders);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        setState(() {
          _suggestions = data.map((e) {
            return _Place(
              displayName: e['display_name'] as String,
              location: LatLng(
                double.parse(e['lat'] as String),
                double.parse(e['lon'] as String),
              ),
            );
          }).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      } else {
        setState(() => _searchError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _searchError = true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _selectPlace(_Place place) {
    _searchCtrl.text = place.displayName.split(',').first.trim();
    _searchFocus.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _pickedLocation = place.location;
      _pickedAddress = place.displayName;
    });
    _mapController.move(place.location, 16);
  }

  // ── Reverse geocode ─────────────────────────────────────────────────────────
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _loadingAddress = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=${point.latitude}&lon=${point.longitude}'
        '&format=json',
      );
      final res = await http.get(uri, headers: _nominatimHeaders);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['display_name'] as String?;
        setState(() => _pickedAddress = address);
      }
    } catch (_) {
      setState(() => _pickedAddress = null);
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────
  Future<void> _goToMyLocation() async {
    setState(() => _locating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _locating = false);
        _showGpsError('Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _locating = false);
          _showGpsError('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _locating = false);
        _showGpsError('Location permission permanently denied. Enable it in Settings.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _pickedLocation = loc);
      _mapController.move(loc, 17);
      await _reverseGeocode(loc);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showGpsError(String msg) {
    if (!mounted) return;
    showThemedDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Location Error'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
        ],
      ),
    );
  }

  // ── Discard guard ───────────────────────────────────────────────────────────
  Future<bool> _onWillPop() async {
    if (_pickedLocation == null) return true;
    bool shouldPop = false;
    await showThemedDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Discard Location?'),
        content: const Text('You have a pin set. Go back without saving?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Discard'),
            onPressed: () {
              shouldPop = true;
              Navigator.of(ctx).pop();
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Stay'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
    return shouldPop;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final LatLng mapCenter =
        widget.initialLocation ?? const LatLng(kMapCenterLat, kMapCenterLng);
    final bool hasPinned = _pickedLocation != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && context.mounted) Navigator.pop(context);
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Pin Your Location'),
          backgroundColor: isDark
              ? kDarkBar.withValues(alpha: 0.9)
              : CupertinoColors.white.withValues(alpha: 0.9),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () async {
              final allow = await _onWillPop();
              if (allow && context.mounted) Navigator.pop(context);
            },
            child: const Icon(CupertinoIcons.back, color: kPrimary),
          ),
        ),
        child: Stack(
          children: [
            // ── Map ────────────────────────────────────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: 15,
                onTap: (tapPosition, point) {
                  setState(() {
                    _pickedLocation = point;
                    _pickedAddress = null;
                  });
                  _reverseGeocode(point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.ecobite.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: const LatLng(kRiderStartLat, kRiderStartLng),
                      width: 80,
                      height: 72,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: kPrimary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimary.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.leaf_arrow_circlepath,
                              color: CupertinoColors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPrimary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Eco Bite',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPinned)
                      Marker(
                        point: _pickedLocation!,
                        width: 50,
                        height: 60,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: Color(0xFFE53935),
                          size: 44,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            // ── Search bar + dropdown ───────────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + kMinInteractiveDimensionCupertino + 8,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCard : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CupertinoTextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      placeholder: 'Search a place…',
                      placeholderStyle: const TextStyle(
                        color: CupertinoColors.systemGrey,
                        fontSize: 14,
                      ),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(CupertinoIcons.search,
                            color: kPrimary, size: 18),
                      ),
                      suffix: _searching
                          ? const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: CupertinoActivityIndicator(radius: 9),
                            )
                          : _searchCtrl.text.isNotEmpty
                              ? CupertinoButton(
                                  padding: const EdgeInsets.only(right: 6),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _suggestions = [];
                                      _showSuggestions = false;
                                    });
                                  },
                                  child: const Icon(
                                      CupertinoIcons.xmark_circle_fill,
                                      color: CupertinoColors.systemGrey3,
                                      size: 18),
                                )
                              : null,
                      decoration: const BoxDecoration(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? CupertinoColors.white
                            : const Color(0xFF1B3A1D),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),

                  // No results / error feedback
                  if (!_searching && _searchCtrl.text.trim().length >= 3 &&
                      !_showSuggestions && _suggestions.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkCard : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _searchError
                                ? CupertinoIcons.exclamationmark_circle
                                : CupertinoIcons.search,
                            color: CupertinoColors.systemGrey,
                            size: 15,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _searchError
                                ? 'No internet connection. Try again.'
                                : 'No places found for "${_searchCtrl.text.trim()}"',
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Suggestions dropdown
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: isDark ? kDarkCard : CupertinoColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _suggestions.asMap().entries.map((entry) {
                            final i = entry.key;
                            final place = entry.value;
                            final isLast = i == _suggestions.length - 1;
                            return GestureDetector(
                              onTap: () => _selectPlace(place),
                              child: Container(
                                color: CupertinoColors.transparent,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 11),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.location,
                                            color: kPrimary,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              place.displayName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? CupertinoColors.white
                                                    : const Color(0xFF1B3A1D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Container(
                                        height: 0.5,
                                        margin: const EdgeInsets.only(left: 40),
                                        color: isDark
                                            ? CupertinoColors.systemGrey.withValues(alpha: 0.3)
                                            : CupertinoColors.systemGrey5,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── GPS "My Location" button ────────────────────────────────────
            Positioned(
              right: 16,
              bottom: hasPinned ? 195 : 115,
              child: GestureDetector(
                onTap: _locating ? null : _goToMyLocation,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark ? kDarkCard : CupertinoColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _locating
                      ? const CupertinoActivityIndicator(radius: 11)
                      : const Icon(CupertinoIcons.location_fill,
                          color: kPrimary, size: 22),
                ),
              ),
            ),

            // ── Bottom info / confirm card ──────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? kDarkCard : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: CupertinoColors.black.withValues(alpha: 0.13),
                          blurRadius: 16,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: hasPinned
                        ? _ConfirmCard(
                            location: _pickedLocation!,
                            address: _pickedAddress,
                            loadingAddress: _loadingAddress,
                            isDark: isDark,
                            onConfirm: () => Navigator.pop(
                              context,
                              MapPickerResult(
                                location: _pickedLocation!,
                                address: _pickedAddress,
                              ),
                            ),
                            onRepin: () => setState(() {
                              _pickedLocation = null;
                              _pickedAddress = null;
                            }),
                          )
                        : _HintCard(
                            hint: widget.hint,
                            isDark: isDark,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hint card (before pin) ────────────────────────────────────────────────────
class _HintCard extends StatelessWidget {
  final String? hint;
  final bool isDark;
  const _HintCard({this.hint, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(CupertinoIcons.hand_draw, color: kPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            hint ?? 'Search a place or tap the map to drop a pin',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? CupertinoColors.white : const Color(0xFF1B3A1D),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Confirm card (after pin) ──────────────────────────────────────────────────
class _ConfirmCard extends StatelessWidget {
  final LatLng location;
  final String? address;
  final bool loadingAddress;
  final bool isDark;
  final VoidCallback onConfirm;
  final VoidCallback onRepin;

  const _ConfirmCard({
    required this.location,
    required this.address,
    required this.loadingAddress,
    required this.isDark,
    required this.onConfirm,
    required this.onRepin,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.location_fill,
                  color: Color(0xFFE53935), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pinned location',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: textColor)),
                  const SizedBox(height: 3),
                  // Address or coords
                  loadingAddress
                      ? const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: CupertinoActivityIndicator(radius: 8),
                        )
                      : Text(
                          address ??
                              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.systemGrey,
                              height: 1.4),
                        ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onRepin,
              child: const Text('Re-pin',
                  style: TextStyle(
                      fontSize: 13, color: CupertinoColors.systemGrey)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: CupertinoButton(
            color: kPrimary,
            borderRadius: BorderRadius.circular(14),
            onPressed: onConfirm,
            child: const Text(
              'Confirm Location',
              style: TextStyle(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

