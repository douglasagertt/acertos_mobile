/// Mirrors `MONTHS_PT` in acertos/src/core/history.py and web/src/types/index.ts.
const monthsPt = <int, String>{
  1: 'Janeiro',
  2: 'Fevereiro',
  3: 'Março',
  4: 'Abril',
  5: 'Maio',
  6: 'Junho',
  7: 'Julho',
  8: 'Agosto',
  9: 'Setembro',
  10: 'Outubro',
  11: 'Novembro',
  12: 'Dezembro',
};

/// The Portuguese month name used in file names and acerto titles.
/// Empty for a month outside 1-12, which the UI never produces.
String monthNameOf(int month) => monthsPt[month] ?? '';
