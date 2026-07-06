/// Mirrors `OWNERS`/`OWNER_*` in acertos/src/core/models.py.
enum Owner {
  bruna,
  douglas,
  compartilhado,
  ignorar;

  /// Portuguese display label — used both in UI and as the wire/storage value.
  String get label => switch (this) {
    Owner.bruna => 'Bruna',
    Owner.douglas => 'Douglas',
    Owner.compartilhado => 'Compartilhado',
    Owner.ignorar => 'Ignorar',
  };

  static Owner fromLabel(String label) => Owner.values.firstWhere(
    (o) => o.label == label,
    orElse: () => Owner.bruna,
  );
}

const cardGroupDouglas = 'Cartão adicional Douglas A Pereira';

/// Mirrors `owner_from_card_group()` in models.py.
Owner ownerFromCardGroup(String cardGroup) {
  if (cardGroup.contains('Douglas')) return Owner.douglas;
  return Owner.bruna;
}
