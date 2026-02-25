import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'map_picker_page.dart';
import 'models/saved_address.dart';
import 'package:latlong2/latlong.dart';

const String kSavedAddressesKey = 'savedAddresses';

class SavedAddressesPage extends StatefulWidget {
  const SavedAddressesPage({super.key});

  @override
  State<SavedAddressesPage> createState() => _SavedAddressesPageState();
}

class _SavedAddressesPageState extends State<SavedAddressesPage> {
  List<SavedAddress> _addresses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final box = Hive.box(kBoxDatabase);
    final raw = box.get(kSavedAddressesKey) as String?;
    setState(() {
      _addresses = SavedAddress.decodeList(raw);
    });
  }

  Future<void> _persist() async {
    final box = Hive.box(kBoxDatabase);
    await box.put(kSavedAddressesKey, SavedAddress.encodeList(_addresses));
    if (mounted) setState(() {});
  }

  // ── Add ────────────────────────────────────────────────────────────────────
  Future<void> _addAddress() async {
    final picked = await Navigator.push<MapPickerResult>(
      context,
      CupertinoPageRoute(
          builder: (_) => const MapPickerPage(hint: 'Tap to pin your location')),
    );
    if (picked == null || !mounted) return;

    // Pre-fill with the first segment of the resolved address (e.g. street name)
    final suggested = picked.address != null
        ? picked.address!.split(',').first.trim()
        : '';

    final label = await _showLabelDialog(initial: suggested);
    if (!mounted) return;
    if (label == null || label.trim().isEmpty) return;

    final newAddr = SavedAddress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label.trim(),
      lat: picked.location.latitude,
      lng: picked.location.longitude,
      isDefault: _addresses.isEmpty,
    );

    _addresses.add(newAddr);
    await _persist();
  }

  // ── Rename label only ──────────────────────────────────────────────────────
  Future<void> _renameAddress(int index) async {
    if (index >= _addresses.length) return;
    final addr = _addresses[index];

    final label = await _showLabelDialog(initial: addr.label);
    if (!mounted) return;
    if (label == null || label.trim().isEmpty) return;

    setState(() {
      _addresses[index] = SavedAddress(
        id: addr.id,
        label: label.trim(),
        lat: addr.lat,
        lng: addr.lng,
        isDefault: addr.isDefault,
      );
    });
    await _persist();
  }

  // ── Edit ───────────────────────────────────────────────────────────────────
  Future<void> _editAddress(int index) async {
    if (index >= _addresses.length) return;
    final addr = _addresses[index];

    final picked = await Navigator.push<MapPickerResult>(
      context,
      CupertinoPageRoute(
        builder: (_) => MapPickerPage(
          hint: 'Move the pin to update',
          initialLocation: LatLng(addr.lat, addr.lng),
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final label = await _showLabelDialog(initial: addr.label);
    if (!mounted) return;
    if (label == null) return;

    setState(() {
      _addresses[index] = SavedAddress(
        id: addr.id,
        label: label.trim().isEmpty ? addr.label : label.trim(),
        lat: picked.location.latitude,
        lng: picked.location.longitude,
        isDefault: addr.isDefault,
      );
    });
    await _persist();
  }

  // ── Set Default ────────────────────────────────────────────────────────────
  Future<void> _setDefault(int index) async {
    setState(() {
      for (int i = 0; i < _addresses.length; i++) {
        _addresses[i] = SavedAddress(
          id: _addresses[i].id,
          label: _addresses[i].label,
          lat: _addresses[i].lat,
          lng: _addresses[i].lng,
          isDefault: i == index,
        );
      }
    });
    await _persist();
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _deleteAddress(int index) async {
    if (index >= _addresses.length) return;
    // Capture before any async gap
    final label = _addresses[index].label;
    final wasDefault = _addresses[index].isDefault;

    final confirmed = await _showDeleteConfirm(label);
    if (!mounted || confirmed != true) return;

    setState(() {
      _addresses.removeAt(index);
      if (wasDefault && _addresses.isNotEmpty) {
        _addresses[0] = SavedAddress(
          id: _addresses[0].id,
          label: _addresses[0].label,
          lat: _addresses[0].lat,
          lng: _addresses[0].lng,
          isDefault: true,
        );
      }
    });
    await _persist();
  }

  // ── Delete confirm dialog ──────────────────────────────────────────────────
  Future<bool?> _showDeleteConfirm(String label) {
    return showThemedDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Remove Address?'),
        content: Text('Remove "$label"?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Label dialog ───────────────────────────────────────────────────────────
  Future<String?> _showLabelDialog({String initial = ''}) async {
    final controller = TextEditingController(text: initial);
    final suggestions = ['🏠 Home', '🏢 Office', '🏫 School', '📍 Other'];

    final result = await showThemedDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            String? errorMsg;
            return CupertinoAlertDialog(
              title: const Text('Address Label'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    controller: controller,
                    placeholder: 'e.g. Home, Office...',
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (errorMsg != null) {
                        setDialogState(() => errorMsg = null);
                      }
                    },
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: suggestions.map((s) {
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              controller.text = s;
                              errorMsg = null;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: kPrimary.withValues(alpha: 0.3)),
                            ),
                            child: Text(s,
                                style: const TextStyle(
                                    fontSize: 12, color: kPrimary)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      // Show inline error — do NOT dismiss
                      setDialogState(() => errorMsg = 'Label cannot be blank.');
                      return;
                    }
                    Navigator.of(ctx).pop(text);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);
    final bgColor = isDark ? kDarkBackground : kBackground;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Saved Addresses',
            style: TextStyle(fontWeight: FontWeight.w700, color: kPrimary)),
        backgroundColor: isDark
            ? kDarkBar.withValues(alpha: 0.95)
            : CupertinoColors.white.withValues(alpha: 0.92),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addAddress,
          child: const Icon(CupertinoIcons.add, color: kPrimary),
        ),
      ),
      child: SafeArea(
        child: _addresses.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _addresses.length,
                itemBuilder: (context, index) {
                  final addr = _addresses[index];
                  return _AddressTile(
                    key: ValueKey(addr.id),
                    address: addr,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                    onSetDefault: () => _setDefault(index),
                    onRename: () => _renameAddress(index),
                    onEdit: () => _editAddress(index),
                    onDelete: () => _deleteAddress(index),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : const Color(0xFF1B3A1D);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(CupertinoIcons.location, size: 48, color: kPrimary),
          ),
          const SizedBox(height: 20),
          Text('No saved addresses',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 8),
          Text(
            'Tap + to pin and save\nyour delivery locations.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF8BAE8B)
                    : CupertinoColors.systemGrey),
          ),
          const SizedBox(height: 28),
          CupertinoButton(
            color: kPrimary,
            borderRadius: BorderRadius.circular(14),
            onPressed: _addAddress,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Add Address',
                  style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Address Tile ──────────────────────────────────────────────────────────────
class _AddressTile extends StatelessWidget {
  final SavedAddress address;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onSetDefault;
  final VoidCallback onRename;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressTile({
    super.key,
    required this.address,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.onSetDefault,
    required this.onRename,
    required this.onEdit,
    required this.onDelete,
  });

  void _showActions(BuildContext context) {
    final brightness = CupertinoTheme.of(context).brightness;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetCtx) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: brightness,
          primaryColor: kPrimary,
          textTheme: CupertinoTextThemeData(primaryColor: kPrimary),
        ),
        child: CupertinoActionSheet(
          title: Text(address.label),
          message: Text(
            '${address.lat.toStringAsFixed(4)}, ${address.lng.toStringAsFixed(4)}',
          ),
          actions: [
            if (!address.isDefault)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  onSetDefault();
                },
                child: const Text('Set as Default'),
              ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                onRename();
              },
              child: const Text('Rename Label'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                onEdit();
              },
              child: const Text('Edit / Repin Location'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                onDelete();
              },
              child: const Text('Remove'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetCtx).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: address.isDefault
            ? Border.all(color: kPrimary, width: 1.5)
            : Border.all(
                color: isDark
                    ? const Color(0xFF2A3E2A)
                    : const Color(0xFFE8F5E9),
              ),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withValues(alpha: isDark ? 0.10 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Icon ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: address.isDefault
                    ? kPrimary.withValues(alpha: 0.12)
                    : (isDark
                        ? const Color(0xFF1F3520)
                        : const Color(0xFFF0FAF0)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                CupertinoIcons.location_fill,
                color:
                    address.isDefault ? kPrimary : CupertinoColors.systemGrey,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // ── Label + coords ────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Text(
                            'Default',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${address.lat.toStringAsFixed(4)}, '
                    '${address.lng.toStringAsFixed(4)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: CupertinoColors.systemGrey),
                  ),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showActions(context),
              child: const Icon(CupertinoIcons.ellipsis,
                  color: CupertinoColors.systemGrey, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

