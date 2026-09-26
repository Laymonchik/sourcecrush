import 'package:flutter/material.dart';

import 'layout.dart';
import 'screen_header.dart';

/// Settings tab. Rows are inert for now; each one becomes real as the
/// corresponding subsystem lands.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: kBottomOverlayInset),
        children: [
          const ScreenHeader(title: 'Settings'),
          _Section(
            title: 'Playback',
            children: const [
              _SettingRow(
                icon: Icons.high_quality,
                label: 'Audio quality',
                value: 'Best available',
              ),
              _SettingRow(
                icon: Icons.download,
                label: 'Downloads',
                value: 'On device only',
              ),
            ],
          ),
          _Section(
            title: 'Library',
            children: const [
              _SettingRow(
                icon: Icons.folder_outlined,
                label: 'Scan music folder',
                value: '3 tracks',
              ),
              _SettingRow(
                icon: Icons.delete_outline,
                label: 'Clear downloads',
                value: '',
              ),
            ],
          ),
          _Section(
            title: 'About',
            children: const [
              _SettingRow(
                icon: Icons.info_outline,
                label: 'sourcecrush',
                value: '0.1.0',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: Colors.white70),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          Icon(
            Icons.chevron_right,
            color: Colors.white.withValues(alpha: 0.25),
            size: 20,
          ),
        ],
      ),
    );
  }
}
