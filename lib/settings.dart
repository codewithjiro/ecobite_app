import 'package:flutter/cupertino.dart';

class SettingsPage extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;
  final bool isBiometricEnabled;
  final ValueChanged<bool> onBiometricsChanged;
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.isDark,
    required this.onThemeChanged,
    required this.isBiometricEnabled,
    required this.onBiometricsChanged,
    required this.onLogout,
  });

  Widget _buildTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required Color color,
    VoidCallback? onTap,
    String? subtitle,
  }) {
    final tileColor = isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    return GestureDetector(
      onTap: onTap,
      child: CupertinoListTile(
        onTap: onTap,
        backgroundColor: tileColor,
        leading: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Icon(icon, size: 18, color: CupertinoColors.white),
        ),
        trailing: trailing ??
            const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey3),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
        additionalInfo: subtitle != null ? Text(subtitle) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(
        CupertinoColors.systemGroupedBackground,
        context,
      ),
      child: CustomScrollView(
        slivers: [
          const CupertinoSliverNavigationBar(largeTitle: Text('Settings')),
          SliverList(
            delegate: SliverChildListDelegate([
              CupertinoListSection.insetGrouped(
                header: const Text('General'),
                backgroundColor: CupertinoColors.transparent,
                children: [
                  _buildTile(
                    icon: CupertinoIcons.moon_fill,
                    title: 'Dark Mode',
                    trailing: CupertinoSwitch(
                      value: isDark,
                      onChanged: onThemeChanged,
                    ),
                    color: CupertinoColors.systemIndigo,
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('Security'),
                backgroundColor: CupertinoColors.transparent,
                children: [
                  _buildTile(
                    icon: CupertinoIcons.lock_shield_fill,
                    title: 'Face ID / Biometrics',
                    color: CupertinoColors.systemGreen,
                    trailing: CupertinoSwitch(
                      value: isBiometricEnabled,
                      onChanged: onBiometricsChanged,
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                backgroundColor: CupertinoColors.transparent,
                children: [
                  _buildTile(
                    icon: CupertinoIcons.arrow_right_circle_fill,
                    title: 'Sign Out',
                    color: CupertinoColors.systemRed,
                    onTap: onLogout,
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }
}