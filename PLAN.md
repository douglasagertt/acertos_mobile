# Acertos Mobile — Implementation Plan

## What this is

A Flutter port of [Acertos](../acertos) (invoice-reconciliation app for Douglas + Bruna) for iOS
and Android. Same core rule: `Douglas deve pagar = Douglas exclusivo + 50% compartilhado`, same
four owners (`Bruna` / `Douglas` / `Compartilhado` / `Ignorar`), same visual identity as the
**Entre Dois** app.

## Decisions already made (2026-07-06)

- **Users**: eventually both Douglas and Bruna use the app with shared/synced data (like Entre
  Dois' 2-person household). **Not built in Phase 1** — see below.
- **Backend, Phase 1**: fully offline, no server. Revisit once the offline app works end-to-end;
  don't build sync infrastructure speculatively.
- **Backend, Phase 2 (later, not now)**: if/when sync is needed, mirror `entre_dois`'s stack —
  a new, separate Supabase project (Postgres + realtime + auth), same pattern as
  `entre_dois/.context/architecture-guidelines.md`. Don't start this until Phase 1 is validated
  in daily use.

This means Phase 1 is architecturally close to the *current desktop/web flow*: one person drives
a reconciliation session, generates the settlement PDF, shares it however they like (WhatsApp,
email, etc.) — just on a phone instead of a laptop, with data kept locally in the app.

## Reference: `entre_dois` conventions to mirror

`../entre_dois` is the couple's other Flutter app and the house style to follow for anything not
dictated by Acertos' own business logic:

- Stack: Flutter · Riverpod · Material 3 · `google_fonts` (Inter). Skip `go_router` and
  `supabase_flutter` for Phase 1 (no auth/routing complexity yet — a single-screen-flow app
  doesn't need a router; add `go_router` if/when Phase 2 introduces auth gating).
- Folder organization by feature (`lib/core/`, `lib/features/<feature>/`, `lib/shared/`) —
  see `entre_dois/.context/architecture-guidelines.md` and `entre_dois/CLAUDE.md`.
- Riverpod convention: reads as `FutureProvider`/plain providers, mutations in `Notifier` classes,
  `ref.invalidate()` after a mutation.
- Philosophy (`entre_dois/.context/architecture-guidelines.md`): "menos código, menos abstração,
  menos boilerplate, menos camadas" — prefer the simplest thing that works over enterprise
  patterns. This matters even more here since Phase 1 has no backend to justify heavy layering.
- Branding: reuse the Entre Dois palette (already Acertos' web palette too, see below), generate
  icons/splash the same way entre_dois does (`flutter_launcher_icons`, `flutter_native_splash`,
  assets under `assets/branding/`).
- Per-user-scoped local storage bug precedent: even though Phase 1 is single-session, if any
  local key ever needs to become per-user later (Phase 2), namespace it then — don't regress into
  a global key that silently mixes two people's data (this bit entre_dois once, see its CLAUDE.md).

## Environment

Flutter SDK is already installed locally: `~/development/flutter` (Flutter 3.44.0 stable, Dart
3.12.0) — same major stack as `entre_dois`, no separate install needed.

## Tech stack (Phase 1)

| Concern | Package | Why |
|---|---|---|
| State management | `flutter_riverpod` | Matches entre_dois; simple providers/notifiers, no backend to abstract over. |
| Theme/typography | `google_fonts` (Inter), Material 3 `ColorScheme` | Matches entre_dois and the Acertos web palette. |
| PDF text extraction (import) | **`pdfrx`** — spike passed 2026-07-06, see below | Resolved: `pdfrx` reproduces pdfplumber's line grouping almost exactly. |
| PDF generation (export) | `pdf` (layout) + `printing` or `share_plus` (share/save) | `pdf`'s widget-like `pw.Table`/`pw.Text` API is a close analogue to reportlab's Platypus story used in `pdf_generator.py`. |
| Local persistence | Plain JSON file via `path_provider` + `dart:io` | History is a handful of monthly records — mirrors `history.py`'s `~/.acertos/history.json` exactly, no need for sqlite/Hive at this scale. |
| File picking | `file_picker` | Pick the invoice PDF from Files/Drive/etc. |
| Icons/splash | `flutter_launcher_icons`, `flutter_native_splash` | Same as entre_dois. |

## The one real technical risk: on-device PDF parsing — RESOLVED (2026-07-06)

`src/core/pdf_reader.py` isn't a generic PDF-to-text tool — its regexes assume the exact line
structure `pdfplumber` produces for the Sicredi invoice layout (date/time prefix, card-group
headers, `Presencial`/`Online` markers, installment tags, trailing `R$` value). Going fully
offline means a Dart PDF library has to reproduce an equivalent line-by-line text structure, or
the regex port won't match anything.

**Spike outcome: `pdfrx` wins decisively, go decision confirmed.**

Method: generated a ground-truth dump via `pdfplumber` (the exact call `pdf_reader.py` uses)
against `acertos/web/e2e/fixtures/invoice.pdf`, then extracted the same PDF with both `pdfrx`
(`PdfDocument.openFile` + `page.loadText().fullText`) and `syncfusion_flutter_pdf`
(`PdfTextExtractor.extractTextLines()`), diffed both against the reference.

Result:
- **`pdfrx`**: near-perfect match for the standard transaction line shape, e.g. pdfplumber gives
  `'09/jun 12:41 Novo Hamburgo Presencial Restaurante Mm E Ef Nh R$ 98,00'` and pdfrx gives the
  *exact same string* on its own line. This held for ~20 of 22 transactions on the tested page.
  Invoice-total lines (`RE_INVOICE_TOTAL`/`RE_PREVIOUS_INVOICE_TOTAL`'s targets) also extract as
  clean standalone lines.
  - **One known edge case to handle in the port**: multi-line annuity/installment entries (e.g.
    "Anuidade Diferenc 03/12") group differently — pdfplumber splits them as `description` /
    `date+value` / `card-last-4-digits` (3 lines), pdfrx groups them as `date+description` (no
    value) / `card-last-4-digits+value` (2 lines). The current Python parser's
    pending-description bridging logic (in `read_pdf()`) won't catch this pdfrx shape as-is and
    would silently drop these entries — needs a small adjustment when porting, not a redesign.
  - License: no commercial terms to track (unlike Syncfusion's Community License), which also
    tipped the choice.
- **`syncfusion_flutter_pdf`**: `extractTextLines()` badly merges multiple transactions into
  single garbled lines with missing spaces (e.g. `"Presencial RestauranteMm
  EEfNhR$98,0009/jun13:24NovoHamburgoPresencialNovo HamburgoOutlet"` — three transactions' worth
  of text glued together). Not usable for the regex-based parsing approach without a full
  rewrite using word/position data instead of lines. **Removed from `pubspec.yaml`.**

**Practical build note**: `pdfrx`'s native `libpdfium` loading relies on Dart's native-assets
build hooks, which don't fire under plain `flutter test` (only under real app builds/runs, e.g.
`flutter run`/`flutter build`) as of Flutter 3.44 stable. For any future test that needs to
exercise real PDF extraction, either run it as an integration test on a real target, or set the
`PDFIUM_PATH` env var to a manually-fetched `libpdfium.so` (same binary the build hook would
otherwise download from `github.com/bblanchon/pdfium-binaries`) and call `pdfrxInitialize()`
(the Dart-only init, not `pdfrxFlutterInitialize()` — the latter needs `path_provider`'s platform
channel, which isn't available under `flutter test`).

Next: proceed to Phase 1 roadmap step 3 (data model + `calculate_totals()` port), then step 6
(PDF import) using `pdfrx`, applying the annuity/installment adjustment noted above.

## Data model (port of `src/core/models.py`)

Direct Dart port, same field names (keeps the mental model identical across web/mobile):

```dart
enum Owner { bruna, douglas, compartilhado, ignorar }
// Display strings stay Portuguese: 'Bruna', 'Douglas', 'Compartilhado', 'Ignorar'

class Transaction {
  final String id; // uuid, client-generated — use `uuid` package
  final String datetime;
  final String city;
  final String purchaseType;
  final String originalDescription;
  final String expenseName;
  final String installment;
  final double value;
  final Owner owner;
  final bool shared;
  final String obs;
  final String source; // 'pdf' | 'manual'
  final String cardGroup;
}

class Totals {
  final double bruna, douglas, sharedTotal, sharedHalf, douglasToPay, grandTotal, ignored;
}
```

## Business logic to port

- **`calculator.py` → `lib/features/settlement/calculate_totals.dart`** — DONE (2026-07-06), see
  `lib/shared/models/{owner,transaction,totals}.dart`, `lib/shared/utils/money.dart`,
  `lib/features/settlement/calculate_totals.dart`, tests in
  `test/features/settlement/calculate_totals_test.dart` (mirrors the 4 e2e spec scenarios: shared-
  split, extorno, reconciliation, delete-row, using synthetic fixtures + `round2()`-derived
  expectations rather than hardcoded numbers, matching the original suite's style).
  **Noted quirk (pre-existing in the Python original, faithfully preserved, not fixed)**: because
  both halves of a shared/`Compartilhado` value are rounded independently
  (`round2(v/2)` for Bruna *and* for Douglas), an odd-cent value like `89.99` rounds each half to
  `45.00`, so the two halves sum to `90.00` — a 1-cent drift the production e2e suite has never
  caught because it only tests fresh imports (nothing pre-marked as shared). Worth knowing if a
  future reconciliation bug report ever traces back to a shared transaction with an odd number of
  cents.
- **`pdf_reader.py` → `lib/features/invoice_import/`**: the regex parsing (date/value/installment
  detection, card-group headers, the "pagamento de fatura nets against last month's total" rule,
  the pending-description-on-previous-line handling) ports fairly directly to Dart `RegExp` once
  the text-extraction spike (above) confirms usable input. Keep the same warnings-list behavior
  (non-fatal parse issues surface as warnings, not exceptions).
- **`pdf_generator.py` → `lib/features/pdf_export/`**: rebuild the settlement PDF with the `pdf`
  package — header, transactions table with owner-colored rows (reuse
  `ROW_COLORS`/`web/tailwind.config.js` hex values), totals summary table, the highlighted
  "Douglas deve pagar à Bruna" box. Exact pixel parity isn't the goal, matching structure/content
  is.
- **`history.py` → `lib/features/history/`**: same shape (list of `{month, year, month_name,
  pdf_path, created_at, updated_at}` records), same `Acerto_<Mês>_<Ano>.pdf` naming, stored as a
  JSON file in the app's documents directory instead of `~/.acertos/`. Generated PDFs get saved
  there too (and shared out via `share_plus`/`printing` rather than downloaded like the browser).

## Folder layout

```
lib/
  core/
    theme/          # ColorScheme + text theme ported from web/tailwind.config.js
    widgets/         # shared design-system primitives (buttons, chips, dialogs)
    constants/
  features/
    invoice_import/  # file picking, PDF text extraction, parsing (pdf_reader.py port)
    transactions/    # transaction list UI, owner/shared editing, manual add
    settlement/      # calculate_totals.dart, summary panel UI
    pdf_export/      # pdf_generator.py port, share/save
    history/         # local history list + storage
  shared/
    models/          # Transaction, Totals, Owner
    utils/           # money formatting (mirror `formatMoney` from web/src/types/index.ts)
  app.dart
  main.dart
```

## Visual identity (exact values, carried over from `acertos/web/tailwind.config.js`)

Same palette as the web app and Entre Dois — port these directly into a Material 3 `ColorScheme`,
don't invent new colors:

- Cream (surfaces): `#FEFAF4` → `#9A9390`
- Lavender (primary), row color for **Bruna**: `#F2EEFF` → `#3D2860` (accent `#A898D0`, text `#8B80BF`)
- Sage (tertiary), row color for **Douglas**: `#EDF3E8` → `#2C4028` (accent `#8AAB6A`, text `#50663F`)
- Charcoal (text/outline): `#F5F5F4` → `#110F0D`

(Note: the inline comments inside `lavender:`/`sage:` in `web/tailwind.config.js` say the
opposite — "row Douglas" next to lavender, "row Bruna" next to sage. Those comments are stale;
the actual mapping above is confirmed by both `rowColors()` in `web/src/types/index.ts` and the
`row-bruna`/`row-douglas` constants at the bottom of the same Tailwind config, which agree with
each other. Trust the code, not the comment.)

Font: Inter (`google_fonts`), matching `fontFamily.sans` in the web Tailwind config.

**Superseded 2026-07-07**: Douglas supplied a UI mockup (HTML/Tailwind, generated by an AI UI
tool reusing Entre Dois' design-system scaffolding) and asked to apply it directly. That palette
is now what `AppColors` in `app_theme.dart` actually contains — background/brand-card/primary/
on-surface/outline/surface-variant/error/inverse-surface/etc., a fuller Material 3 token set than
the plain cream/lavender/sage/charcoal scale above. `brand-lavanda` (`#8B80BF`) and `brand-salvia`
(`#50663F`) are unchanged — they match what this section already had. Font changed to Plus
Jakarta Sans (`GoogleFonts.plusJakartaSansTextTheme()`), matching the mockup's Google Fonts link,
in place of Inter. The row-tinted-background convention above no longer applies either: cards are
a constant `brandCard` color now, with owner conveyed by pill chips instead (see below).

## UI redesign + owner-pill selector (2026-07-07)

Applied Douglas's mockup directly, plus a second one for a new "Resumo" screen:

- **`TransactionRowCard`**: the owner `DropdownButtonFormField` + shared `Checkbox` became four
  tappable pills (Bruna/Douglas/Compartilhado/Ignorar), each calling `applyOwnerChange` directly —
  there's no separate "shared" control anymore since Compartilhado already implies `shared: true`
  (this was already true of the web app's own `handleSharedChange`, which also forced owner to
  Compartilhado — the pill design just removes the now-redundant second control).
  `applySharedChange` was dead code after this and was deleted along with its tests.
- **Toolbar**: "Importar Fatura" (renamed from "Importar PDF" per Douglas's feedback) + "Despesa"
  side by side, "Gerar PDF" full-width below, section title "Transações Recentes" + "Limpar" —
  hidden entirely when the list is empty (Douglas's feedback: don't show a "recent transactions"
  header above an empty-state message).
- **`SummaryPanel`** is now a floating rounded card (`Positioned` in a `Stack`, not a flush bottom
  bar), holding the same metrics as before plus a "TOTAL GERAL" line the mockup added.
- A `FloatingActionButton` was added per the mockup, then **removed** per Douglas's feedback —
  redundant with the toolbar's "Despesa" button.
- **Bug found via the widget-test viewport, not the real device**: `flutter_test`'s default
  800x600 canvas hid several real `RenderFlex` overflow bugs (`Row`s using
  `mainAxisAlignment.spaceBetween` with non-flexible `Text` children, which don't shrink — they
  just overflow once content is wide enough). Fixed by wrapping the vulnerable children in
  `Expanded`/`Flexible`. Worth remembering: widget tests should set a realistic phone-sized
  viewport (`tester.view.physicalSize`) for screens with tight/floating layouts, not rely on the
  default canvas.
- **Bug found via Douglas checking the real device**: the empty-state message centered itself in
  the *full* available height, which put it partly behind the floating summary panel (visually
  faint/cut off). Fixed with matching bottom padding on the empty state, same as the list's.

## Resumo screen + bottom navigation (2026-07-07)

Second mockup applied: a dedicated settlement-summary screen, plus real navigation (the app was
single-screen until now).

- **`AppShell`** (`lib/core/navigation/app_shell.dart`): a Material 3 `NavigationBar` with two
  destinations (Home, Resumo) + `IndexedStack` so switching tabs preserves each screen's state
  (scroll position, open dialogs) instead of rebuilding. No routing package — two flat, always-
  visible tabs don't need go_router's deep-linking/nested-route machinery; revisit if a third
  screen ever needs its own sub-navigation. Each tab keeps its own `Scaffold`/`AppBar`.
- **`ResumoScreen`**: total-geral hero card, Bruna/Douglas bento cards, a shared card (filled in
  "Cada um" and "Ignorados", which the mockup left as an empty div), the dark "Douglas deve pagar"
  result card, and a "Gerar PDF do Acerto" action button.
- **Deliberately dropped from the mockup**: a "+12% vs mês anterior" trend badge (no persisted
  month-over-month history exists yet — Phase 1 step 8 — so that number would have to be
  fabricated) and any interactive "mark as paid" affordance (the "Acerto pendente de
  transferência" status line is kept as a static, always-true statement — nothing in this app
  tracks payment status, so it's honest as a permanent label, just not as a toggleable feature).
- **Bug corrigido 2026-09-01 (device real)**: os cards bento mostravam `totals.bruna`/
  `totals.douglas` sob o rótulo "Gastos Individuais", mas esses campos (herdados de
  `calculator.py`, onde o painel web os rotulava "Cartão Bruna"/"Cartão Douglas") já incluem
  metade do compartilhado — então o card do Douglas exibia exatamente o mesmo número do card
  "Douglas deve pagar" logo abaixo, por definição. `Totals` ganhou `brunaIndividual`/
  `douglasIndividual`, acumulados direto das transações exclusivas em `calculateTotals()` (não
  derivados por `bruna - sharedHalf`, que herdaria a deriva de centavo do arredondamento
  independente das metades). Os campos originais e o PDF exportado ficam inalterados.

- **`generateAndShareSettlementPdf`** (`lib/features/pdf_export/generate_and_share_flow.dart`):
  the validate → month/year dialog → generate → share logic was extracted out of
  `transaction_list_screen.dart` into a shared function once the Resumo screen needed the exact
  same flow behind its own button — avoids duplicating the validation rule and dialog wiring
  between two screens.

## Persistence plan (Phase 1 step 8) — written and implemented 2026-09-01

### The problem

Session state lives only in `TransactionsNotifier` (memory). Closing the app mid-reconciliation
loses everything — with an 80-90 line invoice that is an hour of owner-pill tapping gone. Douglas
asked for a "salvar rascunho" button, a "salvar versão final" button, and a way to reopen past
acertos.

### One correction to the request, then build it as asked

A "salvar rascunho" button alone does **not** fix the data loss: Android can kill the process at
any moment, and whatever was tapped since the last press is still gone. So the plan splits the ask
in two:

- **Autosave (invisible, no button)** — every change to the transaction list is written to disk.
  This is what actually stops the data loss, and it needs no discipline from the user.
- **One button, not two** — the final save names the session (month/year), records it in the
  Acertos list and generates the PDF.

**"Salvar rascunho" was dropped (Douglas, 2026-09-01)**: its only real use was parking one month
half-done to start another, and they never reconcile two months at the same time — one is always
closed before the next starts. With a single working session, autosave already covers everything
that button would have done, so it would be a control that does nothing. That also means
**every record in the history is a closed acerto** — there is no `status` field to carry.

### Files on disk

Under `getApplicationDocumentsDirectory()/acertos/` (`path_provider` is already a transitive
dependency via `printing`/`pdfrx` — it only needs promoting to a direct one in `pubspec.yaml`):

```
acertos/
  session.json          # the live working session, autosaved
  history.json          # index of saved acertos (cheap to list)
  records/<id>.json     # one saved acerto's full transaction list
```

`session.json`:

```json
{ "schemaVersion": 1, "updatedAt": "...", "openRecordId": "<id|null>", "transactions": [ ... ] }
```

`openRecordId` remembers which saved acerto the session was opened from, so saving again updates
that record instead of creating a duplicate.

`history.json` — a list of records, mirroring `history.py`'s shape plus what a mobile list needs:

```json
{ "schemaVersion": 1, "id": "uuid", "month": 8, "year": 2026, "monthName": "Agosto",
  "createdAt": "...", "updatedAt": "...",
  "transactionCount": 89, "grandTotal": 15314.52, "douglasToPay": 7154.20 }
```

The two totals are denormalized into the index purely so the history list renders without opening
every record file; they are recomputed (never trusted) whenever a record is opened.

### Serialization

`Transaction.toJson()`/`fromJson()` on the model itself — no separate DTO layer, per the project's
"menos camadas" philosophy. Keys are the field names; `owner` is stored as its Portuguese label
(`Owner.label`/`Owner.fromLabel` already document themselves as the wire/storage value, which
keeps the JSON readable and identical in meaning to the Python/web side). `Totals` is derived, so
it is never serialized as session state.

### Storage layer

One plain class, `lib/features/history/acertos_store.dart`, constructed with the base
`Directory` (injectable, so tests point it at `Directory.systemTemp`):

- `Future<SessionSnapshot> loadSession()` / `Future<void> saveSession(...)`
- `Future<List<AcertoRecord>> listRecords()` — sorted year/month desc, like `history.list_all()`
- `Future<AcertoRecord> saveRecord(...)` — add-or-update on (month, year), like `add_or_update()`
- `Future<List<Transaction>> loadRecord(String id)` / `Future<void> deleteRecord(String id)`

Every write is atomic: write `<file>.tmp`, then `rename()` over the target, so a process kill
mid-write can never leave a half-written JSON. Every read is wrapped: a corrupt or partial file is
moved aside to `<file>.bak` and treated as empty, surfacing a warning rather than throwing — same
"non-fatal problems become warnings" convention `pdf_reader.dart` already follows.

### Riverpod wiring

- `main()` already awaits `pdfrxFlutterInitialize()`; it also resolves the documents directory,
  builds the store, and loads `session.json` **before** `runApp`. The restored list is injected
  through a `ProviderScope` override, so there is no loading state and no empty-then-populated
  flash on startup.
- `TransactionsNotifier.build()` returns the restored list and calls `ref.listenSelf(...)`
  (available in riverpod 3.3.2) to schedule a debounced save (~400 ms) on every state change.
  Because every mutation goes through the state setter, `add`/`update`/`remove`/`reorder`/
  `replaceAll`/`clear` need no changes at all.
- An `AppLifecycleListener` flushes the pending save on `paused` — on Android the process is
  killed after `onPause`, so without this flush a swipe-away right after an edit still loses it.
- History reads are a `FutureProvider` invalidated after each save/delete, matching the project's
  stated Riverpod convention.

### UI

- **No new button on the Home toolbar.** It keeps the two rows it has today
  (`Importar Fatura | Despesa`, then the full-width PDF button).
- **The save is the existing PDF flow, extended.** `generateAndShareSettlementPdf()` is already
  the single entry point behind both the Home and Resumo buttons, so persistence goes there:
  month/year dialog -> overwrite check -> generate bytes -> save the record -> share. Generation
  failing therefore records nothing; sharing failing still keeps the record.
- **The button label gains the saving.** "Gerar PDF" (Home) and "Gerar PDF do Acerto" (Resumo)
  both become **"Salvar e gerar PDF"** — the button now closes the month, and the label should say
  so rather than leaving the recording invisible.
- **A third `AppShell` tab, "Acertos"** (`Icons.history`), listing saved acertos as cards:
  `Agosto/2026`, "atualizado em", and the "Douglas deve pagar" value. Tapping opens a sheet with
  **Abrir**, **Gerar PDF novamente**, **Excluir**. A third flat tab still doesn't justify
  `go_router` — the `IndexedStack` shell already handles it.

### Rules to honor

- Saving onto an existing (month, year) asks to overwrite, like `main_window.py`'s `save_settlement`.
- Opening a saved acerto while the current session has unsaved content asks first, then replaces
  the list and sets `openRecordId`.
- "Limpar" clears the session and `session.json` — never the history.
- Deleting a record asks, then removes both the index entry and `records/<id>.json`.

### Deviations from `history.py`, on purpose

- The Python/desktop history stores **only a `pdf_path`**; "opening" a past acerto there means
  opening a PDF file. Douglas asked to *reopen* acertos, so each record stores its **transactions**
  — that is the source of truth, and it makes reopening, editing and regenerating possible.
- **The generated PDF is not stored.** It is regenerated from the stored transactions when
  re-sharing: no stale or missing files to handle, storage stays small, and `Printing.sharePdf()`
  takes bytes directly with no temp-file wiring.

### Risks and edge cases

- The app documents directory is private: uninstalling wipes the history, and saved PDFs never
  appear in Files/Downloads. That is the open question already at the bottom of this plan; sharing
  stays the way a PDF leaves the app.
- `schemaVersion: 1` is written from day one so a future field can migrate instead of guess.
- Phase 2 (sync) will need these paths namespaced per user — the `entre_dois` precedent noted at
  the top of this plan. Do it *then*, but don't design a global-key shape now that fights it.
- Every totals value in `history.json` is a cache. Recompute on open; never settle from the index.

### Tests

- `toJson`/`fromJson` round-trip: all four owners, negative values, empty strings, accented text.
- Store tests against `Directory.systemTemp`: save/load, missing file, corrupt JSON -> empty +
  `.bak` kept, no `.tmp` left behind, add-or-update not duplicating a (month, year), delete
  removing both index entry and record file.
- Widget: a container seeded from a restored session renders the list; the history screen with
  records and empty; opening a record replaces the list.
- **The real acceptance test is on the device**: fill the list, swipe the app away from recents,
  reopen — everything is still there. Widget tests cannot exercise a process kill.

### What actually got built (2026-09-01)

Everything above, in the six planned steps, plus these findings:

- **`listenSelf` is a method on `Notifier`, not on `ref`** in riverpod 3.3.2 (it lives in
  `notifier_provider.dart`, and `ref.listenSelf` doesn't compile). Autosave hangs off
  `listenSelf((_, _) => _scheduleSave())` inside `build()`.
- **`_scheduleSave()` returns early when no store is configured.** Without that, every widget test
  ended with `A Timer is still pending even after the widget tree was disposed` — the debounce
  timer outliving the test. The early return also states the intent: no store means no
  persistence, so there is nothing to schedule.
- **Widget tests can't await real `dart:io`.** `flutter_test` runs the test body in a fake-async
  zone where a real file future never completes — a screen awaiting one hangs until
  `pumpAndSettle` times out, and `tester.runAsync` does *not* rescue a future the widget itself is
  already awaiting (verified: the continuation never resumes). So `acertos_screen_test.dart` runs
  against a `FakeAcertosStore extends AcertosStore` that answers from memory, while the real file
  behaviour is covered by `acertos_store_test.dart`'s plain (non-widget) tests against
  `Directory.systemTemp`. Worth remembering for any future screen that touches the filesystem.
- **`AcertosStore` methods are plain and overridable on purpose** — that is what makes the
  in-memory double above a three-line class instead of an interface plus two implementations.
- **Button and dialog copy**: Home and Resumo now read "Salvar e gerar PDF"; the bottom sheet is
  titled "Fechar o acerto", says the acerto will be saved to the Acertos tab, and its action reads
  "Salvar e compartilhar".
- **iOS parity**: nothing platform-specific was written — `path_provider` (iOS 12+, project targets
  iOS 13) plus `dart:io`, with the same code path on both. Not compiled on iOS: no macOS machine
  here, so the iOS build itself is unverified.
- **Verified**: full suite green (82 tests + the pdfium fixture test with `PDFIUM_PATH`) and
  `flutter build apk --debug` succeeds, which is what exercises `path_provider`'s Android plugin
  registration. The Linux desktop target could *not* be run: `flutter run -d linux` fails in
  CMake's install step with `file INSTALL cannot find .../bundle/lib/libpdfium.so` — a pdfrx
  native-assets problem on this machine, unrelated to persistence, and copying the .so in by hand
  doesn't survive the next build. Desktop screenshots are therefore not available as a check for
  this step; on-device is.

### Delivery steps (each one shippable and testable on its own)

1. `Transaction` JSON round-trip + tests. (S)
2. `AcertosStore` with atomic writes and corrupt-file handling + temp-dir tests. (M)
3. Autosave and restore-on-boot. **This alone closes the data-loss complaint.** (M)
4. Save on close: persist the record inside `generateAndShareSettlementPdf`, with the overwrite
   prompt, and relabel the button. (S)
5. The "Acertos" tab: list, open, regenerate PDF, delete. (M)
6. Polish: unsaved-changes guard, empty state, corrupt-session warning surface. (S)

### Decided 2026-09-01

- Generating the PDF *is* closing the acerto — one flow, one button, no separate "salvar versão
  final" action beside it.
- No draft button (see above).

## Roadmap

**Phase 0 — De-risk — DONE (2026-07-06)**
1. ~~PDF text-extraction spike~~ — passed, `pdfrx` chosen. See "on-device PDF parsing" above.

**Phase 1 — Offline MVP**
2. ~~`flutter create --org com.example --project-name acertos_mobile .`~~ — done (org left as
   `com.example` for now, see Open Questions). Still to do: wire up Material 3 theme + Inter font
   + app icon/splash from Entre Dois assets.
3. ~~Port `Transaction`/`Totals`/`Owner` models + `calculate_totals()`, with unit tests ported
   from `web/e2e/tests/*.spec.ts`~~ — done (2026-07-06).
4. ~~Transaction list screen: view/edit owner, shared flag, value, obs; manual "add expense" flow
   (port of `AddExpenseDialog.tsx`); delete row~~ — done (2026-07-06). Card layout instead of a
   literal table port (mobile-appropriate for narrow screens); drag-to-reorder via
   `ReorderableListView`. Riverpod `NotifierProvider<TransactionsNotifier, List<Transaction>>`
   holds session state. Minimal Material 3 theme + Inter added
   (`lib/core/theme/app_theme.dart`) to support owner row colors — full icon/splash generation
   still deferred to the polish pass (step 9). Verified against the real compiled Linux desktop
   binary (screenshots), not just widget tests — caught and fixed one real gap this way: the
   `installment` field wasn't rendered anywhere in the row.
5. ~~Summary panel (port of `SummaryPanel.tsx`): live totals as transactions change~~ — done
   (2026-07-06). Reflowed as a fixed bottom panel (`Wrap` of metrics + the dark "Douglas deve
   pagar" card) instead of the desktop's 270px sidebar — no room for a side panel at phone width.
   `totalsProvider` (`lib/features/settlement/totals_provider.dart`) derives `Totals` from
   `transactionsProvider` reactively. Verified live-update via both a widget test and a real
   screenshot with seeded sample data (all 4 owner types + a negative/ignored value) — the shared
   half-split arithmetic, negative-value sign, and dark highlight card all render correctly.
6. ~~PDF import: file picker → text extraction → parsing → populate transaction list, with the
   same warnings-surface behavior as the web app~~ — done (2026-07-06). `pdf_reader.dart` is a
   pure, synchronous port of `pdf_reader.py` (`parseInvoiceLines(List<String>)`), separated from
   `pdf_text_extractor.dart` (the actual pdfrx I/O) for testability. Includes the pdfrx-specific
   two-line date+description/digits+value pairing fix identified in the Phase 0 spike (annuity/
   installment entries), without which they'd be silently dropped.
   **Validated against the real invoice fixture end-to-end, matching a fresh Python reference run
   exactly**: 80/80 transactions, invoice total R$15.568,34, Bruna R$11.039,43, Douglas
   R$4.528,91 — both annuity entries present and correctly paired. Confirmed twice: once via
   `flutter test` (manual `PDFIUM_PATH`, not auto-fetched — see
   `pdf_reader_fixture_test.dart`'s header for why it doesn't download pdfium itself), and once by
   temporarily wiring the real fixture into the real compiled app on startup and screenshotting
   the populated list + summary panel through the actual `pdfrxFlutterInitialize()` production
   path (not just the test path) — reverted before commit.
   Toolbar re-ordered to match the web's hierarchy: "Importar PDF" is now the primary filled
   button, "Despesa" is outlined/secondary (previously the reverse, since import didn't exist
   yet).
7. ~~PDF export: generate the settlement PDF, save + share (share sheet)~~ — done (2026-07-07).
   `lib/features/pdf_export/pdf_generator.dart` ports `pdf_generator.py` using `pw.MultiPage` +
   `pw.TableHelper.fromTextArray` (with `context:` passed through for header-repeat-across-pages,
   matching reportlab's `repeatRows=1`) — owner-colored rows, the `(÷2 = ...)` shared-value
   suffix, the totals summary table, and the red "Douglas deve pagar" highlight box all carried
   over. `save_pdf_dialog.dart` is the month/year picker (port of `SaveDialog.tsx`); the toolbar's
   new "Gerar PDF" button uses the same validation as web (disabled when empty, and a snackbar
   error if every transaction is ignored/non-positive-value). Uses `printing`'s
   `Printing.sharePdf()` to hand the generated bytes straight to the native share sheet — no
   manual temp-file/share_plus wiring needed.
   **Real bug caught by actually rendering the PDF, not just generating bytes**: the title used an
   em-dash ("—", U+2014), which the base Helvetica font's Latin-1/WinAnsi encoding doesn't cover —
   confirmed by rendering the generated PDF to an image (`pdftoppm`) and by a real "Unable to find
   a font to draw" warning during the unit test. Fixed by using a plain hyphen (Portuguese accents
   and the ÷ symbol are Latin-1 and render fine as-is). Verified end-to-end on the real Android
   phone: filled a manual expense, tapped "Gerar PDF", confirmed month/year, and the native Android
   share sheet opened with the correctly-named `Acerto_Julho_2026.pdf`.
8. ~~Persistence: autosave the working session, save closed acertos, reopen past ones~~ — done
   (2026-09-01). Built exactly as the "Persistence plan" section below describes; that section
   also records what was learned while implementing it.
9. Polish pass: empty states, loading states, error handling for malformed PDFs.

**Phase 2 — Sync (not started until Phase 1 is in daily use)**
10. New Supabase project, mirror `entre_dois`'s auth/household/realtime patterns for a 2-person
    shared invoice. Revisit the data model then — don't design the sync schema now.

## Real Android device validated (2026-07-06)

Everything above had only been run on Linux desktop until this point. Ran the app on a real
connected phone (Samsung, Android 15/API 35) for the first time and hit two real, device-only
bugs neither desktop testing nor widget tests surfaced:

- **Android build failed out of the box**: `file_picker` (11.0.2, current as of this writing)
  fails to compile under Android Gradle Plugin 9.0+ — `cannot find symbol: class
  FilePickerPlugin`. This is a known, currently-unfixed upstream issue (AGP 9 dropped support for
  plugins that apply the Kotlin Gradle Plugin the old way, and most of the plugin ecosystem,
  including file_picker, hasn't migrated to Flutter's new "Built-in Kotlin" model yet — see
  github.com/miguelpruivo/flutter_file_picker/issues/1942). `flutter create` picks the latest AGP
  by default (9.0.1), which is too new for the current plugin ecosystem. **Fix**: pinned
  `android/settings.gradle.kts` to AGP `8.11.1` + Kotlin `2.2.20` — below AGP 9 (avoids the
  file_picker break) but at/above Flutter's own stated minimums for this Flutter version. Revisit
  this pin once file_picker (and the broader plugin ecosystem) migrates.
- **Bottom summary card obscured by Android's edge-to-edge navigation bar**: the "Douglas deve
  pagar" card was partially covered by the phone's gesture nav bar — invisible on desktop, which
  has no such system UI overlay. Fixed with `SafeArea(top: false, child: ...)` wrapping the
  Scaffold body (top:false since the AppBar already handles the status bar).
- **`RenderFlex` overflow on the owner dropdown, real device only**: none of the 3
  `DropdownButtonFormField<Owner>`/`<int>` usages had `isExpanded: true` set, so the widest
  content (specifically "Compartilhado", the longest owner label) overflowed its `Expanded`
  allocation by a few pixels on the phone's actual width — a very well-known Flutter gotcha that
  happened not to trigger during desktop-window testing at a wider size. Fixed by adding
  `isExpanded: true` to all three (`add_expense_dialog.dart`'s Responsável and Mês dropdowns,
  `transaction_row_card.dart`'s owner dropdown).

Both bugs were caught by actually running on hardware and interacting via real touch input
(`adb shell input tap/text`, safe — scoped to the phone over USB, unlike synthetic input on the
shared Linux desktop) and `adb shell screencap`, not by widget tests or desktop screenshots. Full
manual-add-expense flow (open dialog → fill fields → submit → edit owner incl. the longest label
→ auto-check shared → delete) verified working end-to-end on the physical device after the fixes.

## Testing strategy

- Unit-test `calculate_totals()` directly against the same scenarios the Playwright e2e suite
  already validates in `acertos/web/e2e/tests/`: shared-split (50/50 rounding), extorno (negative
  values reduce the original owner's total when un-ignored / show with a minus sign), reconciliation
  (grand total vs. invoice total), delete-row. These are cheap, high-value, and catch any
  arithmetic drift from the Dart port immediately.
- Widget tests for the transaction list (add/edit/delete) and summary panel reactivity.
- Manual, on-device testing for the PDF import spike and the full import → edit → export flow —
  this is the part no test framework substitutes for; use real invoice PDFs, not synthetic ones.

## Open questions to settle before/while building

- `flutter create --org` value / bundle id / package name for App Store & Play Store (entre_dois
  never customized this — still `com.example.entre_dois` — so there's no existing convention to
  copy; pick one now if you plan to eventually publish).
- Where generated settlement PDFs + history live on-device long-term (app documents dir is fine
  for Phase 1; revisit if you want them user-visible in Files/Downloads).
