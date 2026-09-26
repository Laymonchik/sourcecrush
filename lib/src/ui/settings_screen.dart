import 'package:flutter/material.dart';

import '../player_controller.dart';
import 'layout.dart';
import 'screen_header.dart';
import 'theme.dart';

/// Settings tab. Sections become real as the corresponding subsystem lands.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final PlayerController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return ListView(
            padding: const EdgeInsets.only(bottom: kBottomOverlayInset),
            children: [
              const ScreenHeader(title: 'Settings'),
              _Section(
                title: 'Folders',
                children: [
                  if (controller.folders.isEmpty)
                    const _FolderEmptyRow()
                  else
                    for (final folder in controller.folders)
                      _FolderRow(
                        name: folder.name,
                        trackCount: folder.trackCount,
                        onRemove: () =>
                            controller.removeMusicFolder(folder.uri),
                      ),
                ],
              ),
              _Section(
                title: 'Playback',
                children: [
                  _ToggleRow(
                    icon: Icons.shuffle,
                    label: 'Shuffle',
                    value: controller.shuffleEnabled,
                    onChanged: (_) => controller.toggleShuffle(),
                  ),
                  _ValueRow(
                    icon: Icons.repeat,
                    label: 'Repeat',
                    value: switch (controller.loopMode.name) {
                      'all' => 'All',
                      'one' => 'Track',
                      _ => 'Off',
                    },
                    onTap: controller.cycleRepeat,
                  ),
                ],
              ),
              _Section(
                title: 'Library',
                children: [
                  _ValueRow(
                    icon: Icons.refresh,
                    label: 'Rescan library',
                    value: '${controller.tracks.length} tracks',
                    onTap: controller.refreshLibrary,
                  ),
                ],
              ),
              const _Section(
                title: 'About',
                children: [
                  _InfoRow(
                    icon: Icons.info_outline,
                    label: 'sourcecrush',
                    detail: '0.1.0',
                  ),
                ],
              ),
            ],
          );
        },
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
            style: const TextStyle(
              color: SC.textGhost,
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

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.icon,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: SC.textMuted),
            ),
            const SizedBox(width: 16),
            // Flexible rather than ListTile's title slot: the long folder
            // names and the trailing value compete for the same row, and
            // ListTile cannot shrink its title under a wide trailing widget.
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SC.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(color: SC.textFaint, fontSize: 13),
          ),
          const Icon(Icons.chevron_right, color: SC.textGhost, size: 20),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.black,
        activeTrackColor: SC.text,
        inactiveThumbColor: SC.textFaint,
        inactiveTrackColor: Colors.transparent,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: icon,
      label: label,
      trailing: Text(
        detail,
        textAlign: TextAlign.right,
        style: const TextStyle(color: SC.textFaint, fontSize: 13),
      ),
    );
  }
}

/// Empty state for the Folders section: an icon plus a two-line explanation.
class _FolderEmptyRow extends StatelessWidget {
  const _FolderEmptyRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SC.surface,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.create_new_folder_outlined,
              size: 19,
              color: SC.textMuted,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No folders added',
                  style: TextStyle(
                    color: SC.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Add one from the Library tab to scan it for music.',
                  style: TextStyle(color: SC.textFaint, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One registered folder. Tapping the row removes it and drops the
/// persisted permission, so the count sits on the right as a quiet summary.
class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.name,
    required this.trackCount,
    required this.onRemove,
  });

  final String name;
  final int trackCount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: Icons.folder_outlined,
      label: name,
      onTap: onRemove,
      trailing: Text(
        trackCount == 0 ? 'empty' : '$trackCount',
        style: const TextStyle(color: SC.textFaint, fontSize: 13),
      ),
    );
  }
}
