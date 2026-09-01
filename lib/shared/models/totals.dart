/// Mirrors the `Totals` dataclass in acertos/src/core/models.py, plus
/// [brunaIndividual]/[douglasIndividual] — extra fields the Python/web
/// version never needed because its summary panel labelled `bruna`/`douglas`
/// as "Cartão Bruna"/"Cartão Douglas" (total attributed to each person,
/// shared half included). The mobile Resumo screen shows "Gastos
/// Individuais" instead, which is the exclusive spend only.
class Totals {
  const Totals({
    this.bruna = 0.0,
    this.douglas = 0.0,
    this.brunaIndividual = 0.0,
    this.douglasIndividual = 0.0,
    this.sharedTotal = 0.0,
    this.sharedHalf = 0.0,
    this.douglasToPay = 0.0,
    this.grandTotal = 0.0,
    this.ignored = 0.0,
  });

  /// Everything attributed to Bruna: her exclusive spend + half the shared.
  final double bruna;

  /// Everything attributed to Douglas: his exclusive spend + half the shared.
  /// Equal to [douglasToPay] by definition.
  final double douglas;

  /// Bruna's exclusive spend only — no shared half.
  final double brunaIndividual;

  /// Douglas's exclusive spend only — no shared half.
  final double douglasIndividual;

  final double sharedTotal;
  final double sharedHalf;
  final double douglasToPay;
  final double grandTotal;
  final double ignored;
}
