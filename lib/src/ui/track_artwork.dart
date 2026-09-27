import 'dart:io';

import 'package:flutter/material.dart';

import '../models/track.dart';
import 'theme.dart';

/// Cover art for a track, falling back to a neutral placeholder.
///
/// Embedded art is resolved to a local file by the platform extractor, so this
/// never touches the network. Anything that cannot be decoded - a missing
/// picture, a corrupt JPEG, a file:// URI that has gone away - degrades to the
/// grey placeholder rather than an error box.
class TrackArtwork extends StatelessWidget {
  const TrackArtwork({
    super.key,
    required this.track,
    this.size,
    this.borderRadius = 8,
  });

  final Track track;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final artUri = track.artUri;
    final hasLocalArt = artUri != null && artUri.scheme == 'file';

    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: SC.artworkGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.music_note,
        size: (size ?? 48) * 0.42,
        color: const Color(0x4DFFFFFF),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasLocalArt
            ? Image.file(
                File(artUri.toFilePath()),
                fit: BoxFit.cover,
                // Decoding a large JPEG on first paint can miss a frame or
                // fail outright; the placeholder is the right answer either way.
                errorBuilder: (_, _, _) => placeholder,
                gaplessPlayback: true,
              )
            : placeholder,
      ),
    );
  }
}
