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

- **`calculator.py` → `lib/features/settlement/calculate_totals.dart`**: pure function, trivial
  and low-risk port. Do this right after the data model — it's the one piece of logic with
  existing test coverage to mirror (see Testing below).
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

## Roadmap

**Phase 0 — De-risk — DONE (2026-07-06)**
1. ~~PDF text-extraction spike~~ — passed, `pdfrx` chosen. See "on-device PDF parsing" above.

**Phase 1 — Offline MVP**
2. ~~`flutter create --org com.example --project-name acertos_mobile .`~~ — done (org left as
   `com.example` for now, see Open Questions). Still to do: wire up Material 3 theme + Inter font
   + app icon/splash from Entre Dois assets.
3. Port `Transaction`/`Totals`/`Owner` models + `calculate_totals()`, with unit tests ported from
   `web/e2e/tests/*.spec.ts` (see Testing).
4. Transaction list screen: view/edit owner, shared flag, value, obs; manual "add expense" flow
   (port of `AddExpenseDialog.tsx`); delete row.
5. Summary panel (port of `SummaryPanel.tsx`): live totals as transactions change.
6. PDF import: file picker → text extraction → parsing → populate transaction list, with the
   same warnings-surface behavior as the web app.
7. PDF export: generate the settlement PDF, save + share (share sheet).
8. History: local list of past settlements, regenerate/re-share old PDFs.
9. Polish pass: empty states, loading states, error handling for malformed PDFs.

**Phase 2 — Sync (not started until Phase 1 is in daily use)**
10. New Supabase project, mirror `entre_dois`'s auth/household/realtime patterns for a 2-person
    shared invoice. Revisit the data model then — don't design the sync schema now.

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
