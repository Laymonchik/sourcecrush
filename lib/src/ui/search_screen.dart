import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'layout.dart';
import 'screen_header.dart';

/// Search tab. The field is in place; querying YouTube arrives with the
/// yt-dlp backend.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        // Keeps the centred empty state clear of the floating overlay.
        padding: const EdgeInsets.only(bottom: kBottomOverlayInset),
        child: Column(
          children: [
            const ScreenHeader(title: 'Search'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: accent,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Songs, artists, anything',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF16161A),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(color: accent, width: 1.4),
                  ),
                ),
              ),
            ),
            const Expanded(
              child: EmptyState(
                icon: Icons.travel_explore,
                title: 'Search is coming',
                message:
                    'Searching YouTube runs through yt-dlp on your phone, '
                    'which is the next thing to be wired up.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
