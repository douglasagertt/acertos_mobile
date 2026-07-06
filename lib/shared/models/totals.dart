/// Mirrors the `Totals` dataclass in acertos/src/core/models.py.
class Totals {
  const Totals({
    this.bruna = 0.0,
    this.douglas = 0.0,
    this.sharedTotal = 0.0,
    this.sharedHalf = 0.0,
    this.douglasToPay = 0.0,
    this.grandTotal = 0.0,
    this.ignored = 0.0,
  });

  final double bruna;
  final double douglas;
  final double sharedTotal;
  final double sharedHalf;
  final double douglasToPay;
  final double grandTotal;
  final double ignored;
}
