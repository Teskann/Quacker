import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/rate_limit_tracker.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  group('RateLimitTracker.isLimited()', () {
    test('Should report an unknown account as not limited', () {
      expect(RateLimitTracker.isLimited('untracked', '/SearchTimeline', now), isFalse,
          reason: 'An account that never got a 429 should be free to use. Reporting it as limited '
              'would push every request onto the other accounts for no reason');
    });
  });

  group('RateLimitTracker.flag()', () {
    test('Should mark the account as limited until its reset time', () {
      RateLimitTracker.flag('flagged', '/SearchTimeline', now.add(const Duration(minutes: 15)));

      expect(RateLimitTracker.isLimited('flagged', '/SearchTimeline', now), isTrue,
          reason: 'The reset time has not been reached yet, so the account should still count as '
              'limited. Sending another request now would only get another 429');
      expect(
          RateLimitTracker.isLimited(
              'flagged', '/SearchTimeline', now.add(const Duration(minutes: 16))),
          isFalse,
          reason: 'The reset time comes from the x-rate-limit-reset header sent by X, so it '
              'should run out on its own. Otherwise the account stays blocked for the whole '
              'session');
    });

    test('Should keep limits separate for each endpoint', () {
      RateLimitTracker.flag('perEndpoint', '/SearchTimeline', now.add(const Duration(minutes: 15)));

      expect(RateLimitTracker.isLimited('perEndpoint', '/TweetDetail', now), isFalse,
          reason: 'X limits each endpoint on its own, so a 429 on search should leave the same '
              'account free to open a tweet');
    });
  });

  group('RateLimitTracker.clear()', () {
    test('Should remove the limit after a request works', () {
      RateLimitTracker.flag('cleared', '/SearchTimeline', now.add(const Duration(minutes: 15)));
      RateLimitTracker.clear('cleared', '/SearchTimeline');

      expect(RateLimitTracker.isLimited('cleared', '/SearchTimeline', now), isFalse,
          reason: 'A request that works proves the limit is over, so the old reset time should be '
              'dropped rather than waited out');
    });
  });
}
