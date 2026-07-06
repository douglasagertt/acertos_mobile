import 'package:uuid/uuid.dart';

import 'owner.dart';

const _uuid = Uuid();

/// Mirrors the `Transaction` dataclass in acertos/src/core/models.py.
class Transaction {
  Transaction({
    String? id,
    this.datetime = '',
    this.city = '',
    this.purchaseType = '',
    this.originalDescription = '',
    this.expenseName = '',
    this.installment = '',
    this.value = 0.0,
    this.owner = Owner.bruna,
    this.shared = false,
    this.obs = '',
    this.source = 'pdf',
    this.cardGroup = '',
  }) : id = id ?? _uuid.v4();

  final String id;
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
  final String source;
  final String cardGroup;

  Transaction copyWith({
    String? datetime,
    String? city,
    String? purchaseType,
    String? originalDescription,
    String? expenseName,
    String? installment,
    double? value,
    Owner? owner,
    bool? shared,
    String? obs,
    String? source,
    String? cardGroup,
  }) {
    return Transaction(
      id: id,
      datetime: datetime ?? this.datetime,
      city: city ?? this.city,
      purchaseType: purchaseType ?? this.purchaseType,
      originalDescription: originalDescription ?? this.originalDescription,
      expenseName: expenseName ?? this.expenseName,
      installment: installment ?? this.installment,
      value: value ?? this.value,
      owner: owner ?? this.owner,
      shared: shared ?? this.shared,
      obs: obs ?? this.obs,
      source: source ?? this.source,
      cardGroup: cardGroup ?? this.cardGroup,
    );
  }
}
