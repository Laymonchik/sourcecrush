import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'screen_header.dart';

/// Liked songs tab.
class LikedScreen extends StatelessWidget {
  const LikedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        children: [
          ScreenHeader(title: 'Liked'),
          Expanded(
            child: EmptyState(
              icon: Icons.favorite_border,
              title: 'No likes yet',
              message: 'Tap the heart on a track and it will show up here.',
            ),
          ),
        ],
      ),
    );
  }
}
