import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart' show defaultGroupIcon;

void main() {
  final tweet = SavedTweet(id: '1', user: 'dogs', content: '{}', folderId: 'reading');

  group('SavedTweet.fromMap()', () {
    test('Should keep every field written by toMap', () {
      final restored = SavedTweet.fromMap(tweet.toMap());

      expect(restored.id, tweet.id,
          reason: 'The id is the primary key, so it should survive. Losing it makes the row '
              'impossible to find again');
      expect(restored.user, tweet.user,
          reason: 'The column is called user_id while the field is called user, so a rename on '
              'one side only would silently drop the author. Both sides should stay in step');
      expect(restored.content, tweet.content,
          reason: 'The content holds the whole saved tweet as JSON and is what the offline screen '
              'shows, so it should come back byte for byte');
      expect(restored.folderId, tweet.folderId,
          reason: 'The saved tweets screen groups by folder, so the folder should survive');
    });
  });

  group('SavedTweet.copyWith()', () {
    test('Should keep the folder when it is not passed', () {
      expect(tweet.copyWith(content: 'new').folderId, 'reading',
          reason: 'Changing another field should leave the folder alone, not move the tweet out '
              'of it');
    });

    test('Should change the folder when a new one is passed', () {
      expect(tweet.copyWith(folderId: 'later').folderId, 'later',
          reason: 'Moving a tweet to another folder is the normal use of copyWith here, so the '
              'new folder should win');
    });

    test('Should remove the folder when null is passed', () {
      expect(tweet.copyWith(folderId: null).folderId, isNull,
          reason: 'A null folder is a real value here, it means "no folder". The _unset marker '
              'should let callers clear the folder, rather than null meaning "do not change"');
    });
  });

  group('SubscriptionGroup.fromMap()', () {
    Map<String, Object?> group(Object? icon) => {
          'id': 'g1',
          'name': 'Dogs',
          'icon': icon,
          'color': null,
          'created_at': '2026-09-04T12:00:00.000',
        };

    test('Should use the default icon for the old values saved before v2.15.0', () {
      for (final old in [null, 'rss', '']) {
        expect(SubscriptionGroup.fromMap(group(old)).icon, defaultGroupIcon,
            reason: 'Groups coming from a backup older than v2.15.0 have "$old" as their icon, '
                'which the icon pack cannot read, so it should be replaced by the default');
      }
    });

    test('Should keep a real saved icon', () {
      const icon = '{"pack":"material","key":"pets"}';
      expect(SubscriptionGroup.fromMap(group(icon)).icon, icon,
          reason: 'The check for old values should only replace those, and leave every other icon '
              'untouched');
    });

    test('Should keep the colour through its ARGB number', () {
      final restored = SubscriptionGroup.fromMap({
        ...group(defaultGroupIcon),
        'color': const Color(0xFF112233).toARGB32(),
      });

      expect(restored.color?.toARGB32(), 0xFF112233,
          reason: 'The group colour is stored as a number, so it should come back the same, '
              'including the alpha part');
    });
  });

  group('Account.isClean', () {
    test('Should be true when no 404 was ever counted', () {
      final account = Account(id: 'a', authHeader: '{}', screenName: 'a');

      expect(account.isClean, isTrue,
          reason: 'This getter is checked after every request that works, to avoid a database '
              'write. A brand new account should be clean, otherwise every request pays a write');
    });

    test('Should be false once a 404 was counted, even before the mark is set', () {
      final account = Account(id: 'a', authHeader: '{}', screenName: 'a', consecutiveNotFound: 1);

      expect(account.isClean, isFalse,
          reason: 'The counter still has to be reset on the next request that works, so this '
              'account should not be reported as clean and the write should not be skipped');
    });
  });

  group('Account.fromMap()', () {
    test('Should read a missing not found date as null instead of throwing', () {
      final account = Account.fromMap({
        'id': 'a',
        'auth_header': '{}',
        'screen_name': 'a',
        'last_not_found_at': null,
        'consecutive_not_found': null,
      });

      expect(account.lastNotFoundAt, isNull,
          reason: 'A NULL date should stay null. Reading it as a date would mark the account as '
              'broken and take it out of use');
      expect(account.consecutiveNotFound, 0,
          reason: 'Accounts added before these columns existed hold NULL there, so the counter '
              'should fall back to 0 rather than throw');
    });
  });

  Map<String, Object?> row({Object? verified, Object? inFeed, Object? createdAt}) => {
        'id': '1',
        'screen_name': 'dogs',
        'name': 'Dogs',
        'profile_image_url_https': null,
        'verified': verified,
        'created_at': createdAt,
        'in_feed': inFeed,
      };

  group('UserSubscription.fromMap()', () {
    test('Should read SQLite numbers as true and false', () {
      final on = UserSubscription.fromMap(row(verified: 1, inFeed: 1, createdAt: '2026-09-04'));
      final off = UserSubscription.fromMap(row(verified: 0, inFeed: 0, createdAt: '2026-09-04'));

      expect(on.verified, isTrue, reason: 'The number 1 should be read as true');
      expect(on.inFeed, isTrue,
          reason: 'The number 1 should mean the account is shown in the home feed');
      expect(off.verified, isFalse,
          reason: 'The number 0 should be read as false, so the blue check stays hidden');
      expect(off.inFeed, isFalse,
          reason: 'The in_feed column says whether the account shows in the home feed, so 0 '
              'should be read as false. Reading it as true would bring back accounts the user '
              'hid');
    });

    test('Should use the current time when the row has no creation date', () {
      final subscription = UserSubscription.fromMap(row(verified: 1, inFeed: 1, createdAt: null));

      expect(subscription.createdAt.difference(DateTime.now()).abs(),
          lessThan(const Duration(seconds: 5)),
          reason: 'Rows saved before the created_at column existed still have to be sorted, so a '
              'missing date should count as just added');
    });
  });

  group('UserSubscription.toMap()', () {
    test('Should write an afternoon time that fromMap can read back', () {
      final afternoon = DateTime(2026, 9, 4, 13, 37, 5);
      final subscription = UserSubscription(
          id: '1',
          screenName: 'dogs',
          name: 'Dogs',
          profileImageUrlHttps: null,
          verified: false,
          createdAt: afternoon,
          inFeed: true);

      expect(UserSubscription.fromMap(subscription.toMap()).createdAt, afternoon,
          reason: 'created_at is what orders the subscription list, so a time written by toMap '
              'should read back unchanged through fromMap. An afternoon time is used because a '
              'morning one would still pass on a format that loses the hour');
    });
  });
}
