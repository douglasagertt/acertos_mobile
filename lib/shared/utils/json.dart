/// Readers for values coming off disk, none of which throw on the wrong type.
///
/// A stored file can be hand-edited, half-written by an older version, or
/// simply wrong — and losing a whole reconciliation because one field holds a
/// String where a number was expected is a far worse outcome than that field
/// falling back to its default. Anything unreadable degrades to [fallback].
library;

String? stringOrNull(Object? value) => value is String ? value : null;

String stringOr(Object? value, String fallback) => value is String ? value : fallback;

double doubleOr(Object? value, double fallback) => value is num ? value.toDouble() : fallback;

int intOr(Object? value, int fallback) => value is num ? value.toInt() : fallback;

bool boolOr(Object? value, bool fallback) => value is bool ? value : fallback;

/// The list at [value], or an empty one for anything that isn't a list.
List<Object?> listOr(Object? value) => value is List ? value : const [];

/// The maps inside [value], skipping entries that aren't maps.
List<Map<String, dynamic>> mapsIn(Object? value) => [
  for (final entry in listOr(value))
    if (entry is Map<String, dynamic>) entry,
];
