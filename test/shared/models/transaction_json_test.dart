import 'dart:convert';

import 'package:acertos_mobile/shared/models/owner.dart';
import 'package:acertos_mobile/shared/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Transaction roundTrip(Transaction t) =>
      Transaction.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);

  test('survives a full JSON round trip, including id, accents and negatives', () {
    final original = Transaction(
      datetime: '08/ago 17:48',
      city: 'Novo Hamburgo',
      purchaseType: 'Presencial',
      originalDescription: 'Caucakes Novo Hambur',
      expenseName: 'Café da manhã',
      installment: '01/02',
      value: -478.22,
      owner: Owner.compartilhado,
      shared: true,
      obs: 'estorno — conferir',
      source: 'manual',
      cardGroup: cardGroupVirtualBruna,
    );

    final restored = roundTrip(original);

    expect(restored.id, original.id);
    expect(restored.datetime, original.datetime);
    expect(restored.city, original.city);
    expect(restored.purchaseType, original.purchaseType);
    expect(restored.originalDescription, original.originalDescription);
    expect(restored.expenseName, original.expenseName);
    expect(restored.installment, original.installment);
    expect(restored.value, original.value);
    expect(restored.owner, original.owner);
    expect(restored.shared, original.shared);
    expect(restored.obs, original.obs);
    expect(restored.source, original.source);
    expect(restored.cardGroup, original.cardGroup);
  });

  test('keeps every owner distinguishable across the round trip', () {
    for (final owner in Owner.values) {
      expect(roundTrip(Transaction(owner: owner)).owner, owner);
    }
  });

  test('fills in defaults for a record missing every optional field', () {
    final restored = Transaction.fromJson({'id': 'abc'});

    expect(restored.id, 'abc');
    expect(restored.value, 0.0);
    expect(restored.owner, Owner.bruna);
    expect(restored.shared, isFalse);
    expect(restored.source, 'pdf');
    expect(restored.expenseName, isEmpty);
  });

  test('generates an id when the stored record has none', () {
    expect(Transaction.fromJson(const {}).id, isNotEmpty);
  });

  // Regression: these used to throw a TypeError, which took down the whole
  // session load (and with it every transaction in it) over one bad field.
  test('a field of the wrong type falls back to its default instead of throwing', () {
    final restored = Transaction.fromJson(const {
      'id': 42,
      'datetime': 7,
      'value': '50,00',
      'owner': 99,
      'shared': 1,
      'expenseName': ['Mercado'],
    });

    expect(restored.id, isNotEmpty); // a fresh uuid, not the number 42
    expect(restored.datetime, isEmpty);
    expect(restored.value, 0.0);
    expect(restored.owner, Owner.bruna);
    expect(restored.shared, isFalse);
    expect(restored.expenseName, isEmpty);
  });

  test('an integer value is read as a double', () {
    expect(Transaction.fromJson(const {'value': 90}).value, 90.0);
  });

  test('an unknown owner label falls back to Bruna rather than dropping the row', () {
    // Owner.fromLabel's documented fallback: a row with an unreadable owner
    // still loads, and shows up in the list to be re-assigned by hand.
    expect(Transaction.fromJson(const {'owner': 'Ninguém'}).owner, Owner.bruna);
  });
}
