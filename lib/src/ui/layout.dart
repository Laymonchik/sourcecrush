/// Shared layout metrics for the floating bottom overlay.
///
/// The mini player and navigation pill are drawn on top of the page, so
/// scrollable content needs bottom padding to be able to scroll clear of them,
/// and centred content needs it to avoid sitting underneath.
library;

/// Height reserved at the bottom of scrollable content so the last item can
/// scroll above the floating player and navigation pill.
const kBottomOverlayInset = 148.0;
