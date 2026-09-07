import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/account_selector.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  Account account(String id, {DateTime? lastNotFoundAt}) =>
      Account(id: id, authHeader: '{}', screenName: id, lastNotFoundAt: lastNotFoundAt);

  group('AccountSelector.pick()', () {
    test('Should prefer an account that is not rate limited on this endpoint', () {
      final selector = AccountSelector([account('limited'), account('healthy')], now,
          isRateLimited: (a) => a.id == 'limited');

      expect(selector.pick(exclude: {})?.id, 'healthy',
          reason: 'Rate limits are per endpoint, and one account here is free of them, so that '
              'one should be chosen. Only one is healthy in each test because pick draws at '
              'random among the healthy accounts');
    });

    test('Should skip an account marked not found while its cooldown is running', () {
      final selector = AccountSelector([
        account('broken', lastNotFoundAt: now.subtract(notFoundCooldown ~/ 2)),
        account('healthy')
      ], now);

      expect(selector.pick(exclude: {})?.id, 'healthy',
          reason: 'Many 404s in a row mean the login of that account is probably broken, so it '
              'should not be tried again before notFoundCooldown has passed');
    });

    test('Should use an account again once its cooldown has passed', () {
      final recovered = account('recovered', lastNotFoundAt: now.subtract(notFoundCooldown * 2));
      final selector = AccountSelector([recovered], now);

      expect(selector.pick(exclude: {})?.id, 'recovered',
          reason: 'The mark is a cooldown and not a ban, so an account whose login was fixed '
              'should come back into use on its own');
    });

    test('Should still return a marked account when no healthy one is left', () {
      final selector =
          AccountSelector([account('broken', lastNotFoundAt: now)], now, isRateLimited: (_) => true);

      expect(selector.pick(exclude: {}), isNotNull,
          reason: 'The marks should only change the order. A real request should always be sent '
              'while an account exists, so errors come from real answers and not from a guess');
    });

    test('Should never return an account that was already tried for this request', () {
      final selector = AccountSelector([account('a'), account('b')], now);

      expect(selector.pick(exclude: {'a'})?.id, 'b',
          reason: 'Account a was already tried and failed, so it should not come back. Trying it '
              'again would waste a request and could loop on the same error');
      expect(selector.pick(exclude: {'a', 'b'}), isNull,
          reason: 'Null is what stops the retry loop, so once every account has been tried it '
              'should be returned. Anything else would loop forever');
    });

    test('Should return null when there is no account at all', () {
      expect(AccountSelector([], now).pick(exclude: {}), isNull,
          reason: 'With no account there is nothing to choose, so null should come back. That is '
              'what tells the caller to fall back to a guest request');
    });
  });
}
