import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../acertos_store.dart';

/// The local store, overridden in `main()` with one rooted at the app
/// documents directory. Null means "no persistence configured" — the case in
/// widget tests, where nothing should touch the filesystem, and the fallback
/// if the documents directory can't be resolved at startup.
final acertosStoreProvider = Provider<AcertosStore?>((ref) => null);

/// The working session as restored from disk before the first frame.
/// Overridden in `main()`; empty everywhere else.
final restoredSessionProvider = Provider<SessionSnapshot>((ref) => const SessionSnapshot());

/// The closed acertos, newest first. Invalidate after saving or deleting one.
final acertoRecordsProvider = FutureProvider<List<AcertoRecord>>((ref) async {
  final store = ref.watch(acertosStoreProvider);
  return store == null ? const <AcertoRecord>[] : store.listRecords();
});
