import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';

void main() {
  // The text of a tombstone falls back to a translated string.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await L10n.load(const Locale('en'));
  });

  /// What the feed cache does between two launches: store the chains, read them back.
  TweetChain throughTheCache(TweetChain chain) =>
      TweetChain.fromJson(jsonDecode(jsonEncode(chain.toJson())) as Map<String, dynamic>);

  group('TweetChain.fromJson()', () {
    test('Should still read a tombstone as a tombstone after it went through the cache', () {
      final chain = TweetChain(id: '1', tweets: [TweetWithCard.tombstone({})], isPinned: false);

      expect(throughTheCache(chain).tweets.single.isTombstone, isTrue,
          reason: 'A tombstone is rendered as an error message. One that loses its flag in the '
              'cache is rendered as an ordinary tweet instead, and it carries neither an author '
              'nor a display text range, so building its tile throws');
    });
  });
}
