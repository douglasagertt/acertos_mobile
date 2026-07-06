import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Global test setup, auto-loaded by `flutter test` for every test in this
/// directory tree. Disables google_fonts' runtime network fetch so widget
/// tests don't hit the network for the Inter font (falls back to the
/// platform default font instead) — otherwise tests retry/slow down
/// waiting on font downloads that a sandboxed/offline test run may never
/// complete.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
