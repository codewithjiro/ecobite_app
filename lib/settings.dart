import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'saved_addresses_page.dart';

class SettingsPage extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final bool isBiometricEnabled;
  final Future<void> Function(bool) onBiometricsChanged;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.isBiometricEnabled,
    required this.onBiometricsChanged,
    required this.onLogout,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ── Section header ──────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: widget.isDark
                ? CupertinoColors.systemGrey
                : const Color(0xFF7A9E7E),
          ),
        ),
      );

  // ── Single row tile ─────────────────────────────────────────────────────────
  Widget _tile({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    final isDark = widget.isDark;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final textColor = isDestructive
        ? CupertinoColors.systemRed
        : (isDark ? CupertinoColors.white : const Color(0xFF1B3A1D));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        color: cardColor,
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: iconBg.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: CupertinoColors.white),
            ),
            const SizedBox(width: 14),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Trailing
            trailing ??
                (onTap != null
                    ? const Icon(CupertinoIcons.chevron_forward,
                        size: 15, color: CupertinoColors.systemGrey3)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }

  // ── Card wrapper (groups tiles with rounded corners + dividers) ─────────────
  Widget _card(List<Widget> tiles) {
    final isDark = widget.isDark;
    final cardColor = isDark ? kDarkCard : CupertinoColors.white;
    final divColor = isDark
        ? CupertinoColors.systemGrey.withValues(alpha: 0.15)
        : CupertinoColors.systemGrey5;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              tiles[i],
              if (i < tiles.length - 1)
                Container(
                  height: 0.5,
                  margin: const EdgeInsets.only(left: 62),
                  color: divColor,
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? kDarkBackground : kBackground;
    final box = Hive.box(kBoxDatabase);
    final String username = box.get('username') ?? '—';
    final String displayName = username.isNotEmpty
        ? '${username[0].toUpperCase()}${username.substring(1)}'
        : username;
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text(
              'Settings',
              style: TextStyle(
                color: kPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            backgroundColor: isDark
                ? kDarkBar.withValues(alpha: 0.95)
                : CupertinoColors.white.withValues(alpha: 0.92),
          ),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 32 + bottomInset),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Profile card ───────────────────────────────────────────
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1B3A1C), const Color(0xFF0E2210)]
                          : [kPrimary, const Color(0xFF388E3C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: kPrimary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: CupertinoColors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          color: CupertinoColors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name + tag
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: CupertinoColors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: CupertinoColors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'EcoBite Member',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Since 2026',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.leaf_arrow_circlepath,
                        color: CupertinoColors.white,
                        size: 28,
                      ),
                    ],
                  ),
                ),

                // ── Delivery ──────────────────────────────────────────────
                _sectionHeader('Delivery'),
                _card([
                  _tile(
                    icon: CupertinoIcons.location_fill,
                    iconBg: const Color(0xFF00897B),
                    title: 'My Addresses',
                    onTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                          builder: (_) => const SavedAddressesPage()),
                    ),
                  ),
                ]),

                // ── General ───────────────────────────────────────────────
                _sectionHeader('General'),
                _card([
                  _tile(
                    icon: CupertinoIcons.moon_fill,
                    iconBg: CupertinoColors.systemIndigo,
                    title: 'Dark Mode',
                    trailing: CupertinoSwitch(
                      value: widget.isDark,
                      onChanged: widget.onThemeChanged,
                      activeTrackColor: kPrimary,
                    ),
                  ),
                ]),

                // ── Security ──────────────────────────────────────────────
                _sectionHeader('Security'),
                _card([
                  _tile(
                    icon: CupertinoIcons.lock_shield_fill,
                    iconBg: kPrimary,
                    title: 'Face ID / Biometrics',
                    trailing: CupertinoSwitch(
                      value: widget.isBiometricEnabled,
                      onChanged: (v) => widget.onBiometricsChanged(v),
                      activeTrackColor: kPrimary,
                    ),
                  ),
                ]),

                // ── Account ───────────────────────────────────────────────
                _sectionHeader('Account'),
                _card([
                  _tile(
                    icon: CupertinoIcons.arrow_right_circle_fill,
                    iconBg: CupertinoColors.systemRed,
                    title: 'Sign Out',
                    isDestructive: true,
                    onTap: widget.onLogout,
                  ),
                ]),

                // ── Version footer ─────────────────────────────────────────
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      const Icon(CupertinoIcons.leaf_arrow_circlepath,
                          color: kPrimary, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        'EcoBite — Eat clean. Tread lightly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? CupertinoColors.systemGrey
                              : const Color(0xFF7A9E7E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'v1.0.0',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? CupertinoColors.systemGrey2
                              : CupertinoColors.systemGrey3,
                        ),
                      ),
                    ],
                  ),
                ),

              ]),
            ),
          ),
        ],
      ),
    );
  }
}

