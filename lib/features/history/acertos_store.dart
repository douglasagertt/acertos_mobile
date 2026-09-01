import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../core/constants/months_pt.dart';
import '../../shared/models/totals.dart';
import '../../shared/utils/json.dart';
import '../../shared/models/transaction.dart';

/// Bumped only when a stored shape changes in a way a future version has to
/// migrate. Written from day one so that version never has to guess.
const _schemaVersion = 1;

const _uuid = Uuid();

/// One closed acerto, as it appears in the history index.
///
/// [grandTotal] and [douglasToPay] are denormalized here purely so the
/// Acertos list renders without opening every record file — they are a cache,
/// never the source of truth. Anything that settles money recomputes them
/// from the record's transactions.
class AcertoRecord {
  const AcertoRecord({
    required this.id,
    required this.month,
    required this.year,
    required this.monthName,
    required this.createdAt,
    required this.updatedAt,
    required this.transactionCount,
    required this.grandTotal,
    required this.douglasToPay,
  });

  final String id;
  final int month;
  final int year;
  final String monthName;

  /// ISO-8601, unlike history.py's display-formatted timestamps — it sorts and
  /// parses reliably, and the UI formats it at render time instead.
  final String createdAt;
  final String updatedAt;

  final int transactionCount;
  final double grandTotal;
  final double douglasToPay;

  String get title => '$monthName/$year';

  /// Same naming as `history.pdf_filename()` in the Python app.
  String get pdfFilename => 'Acerto_${monthName}_$year.pdf';

  /// "01/09/2026 21:04" — falls back to the raw value if it isn't parseable.
  String get updatedAtLabel {
    final at = DateTime.tryParse(updatedAt);
    if (at == null) return updatedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.day)}/${two(at.month)}/${at.year} ${two(at.hour)}:${two(at.minute)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'month': month,
    'year': year,
    'monthName': monthName,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'transactionCount': transactionCount,
    'grandTotal': grandTotal,
    'douglasToPay': douglasToPay,
  };

  factory AcertoRecord.fromJson(Map<String, dynamic> json) {
    final month = intOr(json['month'], 1);
    return AcertoRecord(
      id: stringOrNull(json['id']) ?? _uuid.v4(),
      month: month,
      year: intOr(json['year'], 0),
      monthName: stringOr(json['monthName'], monthsPt[month] ?? ''),
      createdAt: stringOr(json['createdAt'], ''),
      updatedAt: stringOr(json['updatedAt'], ''),
      transactionCount: intOr(json['transactionCount'], 0),
      grandTotal: doubleOr(json['grandTotal'], 0.0),
      douglasToPay: doubleOr(json['douglasToPay'], 0.0),
    );
  }
}

/// The working session as restored from disk at startup.
class SessionSnapshot {
  const SessionSnapshot({this.transactions = const [], this.openRecordId, this.warnings = const []});

  final List<Transaction> transactions;

  /// The saved acerto this session was opened from, if any — so saving again
  /// updates that record instead of creating a second one for the same month.
  final String? openRecordId;

  /// Non-fatal problems (an unreadable session file, storage unavailable),
  /// surfaced to the user instead of thrown — the same convention
  /// `pdf_reader.dart` uses for parse problems.
  final List<String> warnings;
}

/// Local persistence for the working session and the closed acertos.
///
/// Plain JSON files under a directory the caller provides (the app documents
/// directory in production, a temp directory in tests) — the history is a
/// handful of monthly records, so there is nothing here a database would do
/// better. Identical on iOS and Android: `dart:io` plus a path from
/// `path_provider`, no platform-specific code.
class AcertosStore {
  AcertosStore(this.baseDir);

  final Directory baseDir;

  File get _sessionFile => File('${baseDir.path}/session.json');
  File get _historyFile => File('${baseDir.path}/history.json');
  File _recordFile(String id) => File('${baseDir.path}/records/$id.json');

  // — the working session —

  Future<SessionSnapshot> loadSession() async {
    final warnings = <String>[];
    final json = await _readJson(_sessionFile, warnings, 'a sessão em andamento');
    if (json == null) return SessionSnapshot(warnings: warnings);

    return SessionSnapshot(
      transactions: [for (final t in mapsIn(json['transactions'])) Transaction.fromJson(t)],
      openRecordId: stringOrNull(json['openRecordId']),
      warnings: warnings,
    );
  }

  Future<void> saveSession(List<Transaction> transactions, {String? openRecordId}) async {
    await _writeJson(_sessionFile, _sessionJson(transactions, openRecordId));
  }

  /// Synchronous twin of [saveSession], for the app-backgrounded flush: both
  /// Android and iOS can kill a backgrounded process at any moment, so that
  /// write has to finish before the lifecycle callback returns rather than
  /// waiting on the event loop.
  void saveSessionSync(List<Transaction> transactions, {String? openRecordId}) {
    _writeJsonSync(_sessionFile, _sessionJson(transactions, openRecordId));
  }

  Map<String, dynamic> _sessionJson(List<Transaction> transactions, String? openRecordId) => {
    'schemaVersion': _schemaVersion,
    'updatedAt': DateTime.now().toIso8601String(),
    'openRecordId': openRecordId,
    'transactions': [for (final t in transactions) t.toJson()],
  };

  // — closed acertos —

  /// Newest first, like `history.list_all()`.
  Future<List<AcertoRecord>> listRecords() async {
    final json = await _readJson(_historyFile, null, null);
    final records = [for (final r in mapsIn(json?['records'])) AcertoRecord.fromJson(r)];
    records.sort((a, b) => b.year != a.year ? b.year.compareTo(a.year) : b.month.compareTo(a.month));
    return records;
  }

  Future<AcertoRecord?> findRecord(int month, int year) async {
    final records = await listRecords();
    for (final r in records) {
      if (r.month == month && r.year == year) return r;
    }
    return null;
  }

  /// Add-or-update on (month, year), like `history.add_or_update()` — saving
  /// the same month twice updates that acerto instead of stacking duplicates.
  Future<AcertoRecord> saveRecord({
    required List<Transaction> transactions,
    required Totals totals,
    required int month,
    required int year,
  }) async {
    final records = await listRecords();
    final existing = records.where((r) => r.month == month && r.year == year).firstOrNull;
    final now = DateTime.now().toIso8601String();

    final record = AcertoRecord(
      id: existing?.id ?? _uuid.v4(),
      month: month,
      year: year,
      monthName: monthsPt[month] ?? '',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      transactionCount: transactions.length,
      grandTotal: totals.grandTotal,
      douglasToPay: totals.douglasToPay,
    );

    // Transactions first: an interrupted save leaves an index entry pointing
    // at a written file, never an entry pointing at nothing.
    await _writeJson(_recordFile(record.id), {
      'schemaVersion': _schemaVersion,
      'id': record.id,
      'transactions': [for (final t in transactions) t.toJson()],
    });
    await _writeIndex([for (final r in records) if (r.id != record.id) r, record]);
    return record;
  }

  Future<List<Transaction>> loadRecord(String id) async {
    final json = await _readJson(_recordFile(id), null, null);
    return [for (final t in mapsIn(json?['transactions'])) Transaction.fromJson(t)];
  }

  Future<void> deleteRecord(String id) async {
    final records = await listRecords();
    await _writeIndex([for (final r in records) if (r.id != id) r]);
    final file = _recordFile(id);
    if (file.existsSync()) await file.delete();
  }

  Future<void> _writeIndex(List<AcertoRecord> records) async {
    await _writeJson(_historyFile, {
      'schemaVersion': _schemaVersion,
      'records': [for (final r in records) r.toJson()],
    });
  }

  // — file plumbing —

  /// Atomic: a full temp file is renamed over the target, so a process killed
  /// mid-write can never leave a truncated JSON where the session used to be.
  Future<void> _writeJson(File file, Map<String, dynamic> json) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json), flush: true);
    await tmp.rename(file.path);
  }

  void _writeJsonSync(File file, Map<String, dynamic> json) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(json), flush: true);
    tmp.renameSync(file.path);
  }

  /// Returns null for "nothing stored yet". A file that exists but doesn't
  /// parse is moved aside to `.bak` — the bytes are kept in case they can be
  /// recovered by hand — and reported through [warnings] rather than thrown.
  Future<Map<String, dynamic>?> _readJson(File file, List<String>? warnings, String? label) async {
    if (!file.existsSync()) return null;
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      try {
        await file.rename('${file.path}.bak');
      } catch (_) {
        // Nothing else to try; the unreadable file stays where it is.
      }
      if (warnings != null && label != null) {
        warnings.add('Não foi possível ler $label. O arquivo foi guardado como cópia e a tela começou vazia.');
      }
      return null;
    }
  }
}
