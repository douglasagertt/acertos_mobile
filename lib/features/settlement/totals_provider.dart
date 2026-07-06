import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../transactions/providers/transactions_provider.dart';
import 'calculate_totals.dart';

/// Derived, read-only: recomputes whenever `transactionsProvider` changes.
/// Same role as the `useEffect` recalculation in web/src/App.tsx, but
/// synchronous and without a network round-trip since the calculation runs
/// on-device.
final totalsProvider = Provider((ref) => calculateTotals(ref.watch(transactionsProvider)));
