import 'package:flutter/material.dart';

import '../library/likes_controller.dart';
import '../player_controller.dart';
import 'home_screen.dart';
import 'liked_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'mini_player.dart';
import 'theme.dart';

/// Top level navigation: the four main destinations plus the persistent
/// mini player, which floats above the navigation pill.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.likes,
  });

  final PlayerController controller;
  final LikesController likes;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pick up files added by the download pipeline while we were backgrounded.
    if (state == AppLifecycleState.resumed) {
      widget.controller.refreshLibrary();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // The player and navigation float on top of the page, so the content
      // behind them keeps scrolling instead of being pushed up by a reserved
      // bottom bar.
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(
                controller: widget.controller,
                likes: widget.likes,
              ),
              const SearchScreen(),
              LikedScreen(
                likes: widget.likes,
                player: widget.controller,
              ),
              SettingsScreen(controller: widget.controller),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomArea(
              controller: widget.controller,
              index: _index,
              onChanged: (value) => setState(() => _index = value),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  final PlayerController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(controller: controller),
          _NavPill(index: index, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// One destination in the navigation pill.
class _NavDestination {
  const _NavDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _destinations = <_NavDestination>[
  _NavDestination(
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
    label: 'Home',
  ),
  _NavDestination(
    icon: Icons.search_outlined,
    activeIcon: Icons.search,
    label: 'Search',
  ),
  _NavDestination(
    icon: Icons.favorite_border,
    activeIcon: Icons.favorite,
    label: 'Liked',
  ),
  _NavDestination(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
];

/// Floating stadium-shaped navigation bar. It hugs its content and only the
/// selected destination shows a label, so the pill grows and shrinks as you
/// move between tabs.
class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onChanged});

  static const _duration = Duration(milliseconds: 220);

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Center(
        child: AnimatedSize(
          duration: _duration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: SC.surfaceHigh,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SC.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  _NavItem(
                    destination: _destinations[i],
                    active: i == index,
                    accent: SC.text,
                    onTap: () => onChanged(i),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  static const _duration = Duration(milliseconds: 220);

  final _NavDestination destination;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      active ? destination.activeIcon : destination.icon,
      color: active ? accent : SC.textMuted,
      size: 22,
    );

    // Only the selected destination expands to show its label, which is what
    // gives the pill its shifting, rounded silhouette.
    final content = active
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: 8),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          )
        : SizedBox(width: 48, height: 44, child: Center(child: icon));

    return Semantics(
      button: true,
      selected: active,
      label: destination.label,
      child: Material(
        color: active ? SC.surfaceHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOutCubic,
            height: 44,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
