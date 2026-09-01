import 'package:uuid/uuid.dart';

import '../utils/json.dart';
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

  /// Field names double as JSON keys, and `owner` is stored as its Portuguese
  /// label — the same wire value the Python/web side uses (see [Owner.label]),
  /// which keeps a saved acerto readable and portable between the two apps.
  Map<String, dynamic> toJson() => {
    'id': id,
    'datetime': datetime,
    'city': city,
    'purchaseType': purchaseType,
    'originalDescription': originalDescription,
    'expenseName': expenseName,
    'installment': installment,
    'value': value,
    'owner': owner.label,
    'shared': shared,
    'obs': obs,
    'source': source,
    'cardGroup': cardGroup,
  };

  /// Every field falls back to its default when missing or of an unexpected
  /// type, so a file written by an older (or slightly wrong) version loads as
  /// a usable transaction instead of throwing away the whole acerto.
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: stringOrNull(json['id']),
    datetime: stringOr(json['datetime'], ''),
    city: stringOr(json['city'], ''),
    purchaseType: stringOr(json['purchaseType'], ''),
    originalDescription: stringOr(json['originalDescription'], ''),
    expenseName: stringOr(json['expenseName'], ''),
    installment: stringOr(json['installment'], ''),
    value: doubleOr(json['value'], 0.0),
    owner: Owner.fromLabel(stringOr(json['owner'], '')),
    shared: boolOr(json['shared'], false),
    obs: stringOr(json['obs'], ''),
    source: stringOr(json['source'], 'pdf'),
    cardGroup: stringOr(json['cardGroup'], ''),
  );

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
