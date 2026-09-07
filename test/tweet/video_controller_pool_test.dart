import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/video_controller_pool.dart';

void main() {
  Future<PooledVideo> neverFinishesBuilding() => Completer<PooledVideo>().future;

  group('VideoControllerPool.acquire()', () {
    test('Should keep a player so it is not built again on the next call', () {
      final pool = VideoControllerPool(maxSize: 5);
      final first = pool.acquire('tweet:0', neverFinishesBuilding);
      final second = pool.acquire('tweet:0', neverFinishesBuilding);

      expect(identical(first, second), isTrue,
          reason: 'Scrolling back to a tweet should reuse the player that is already playing, '
              'rather than build a new one and start the video again from the beginning');
    });

    test('Should remove the oldest unused player when the pool is full', () {
      final pool = VideoControllerPool(maxSize: 2);
      for (final key in ['a', 'b', 'c']) {
        pool.acquire(key, neverFinishesBuilding);
        pool.release(key);
      }

      expect(pool.contains('a'), isFalse,
          reason: 'Player a is the oldest unused one, so it should be the one dropped');
      expect(pool.contains('b'), isTrue,
          reason: 'Only one player has to go to get back to the size limit of 2, so b should stay');
      expect(pool.contains('c'), isTrue,
          reason: 'Player c is the newest one, so it should stay');
    });

    test('Should count a player as the newest again when it is asked for again', () {
      final pool = VideoControllerPool(maxSize: 2);
      pool.acquire('a', neverFinishesBuilding);
      pool.release('a');
      pool.acquire('b', neverFinishesBuilding);
      pool.release('b');

      pool.acquire('a', neverFinishesBuilding);
      pool.release('a');
      pool.acquire('c', neverFinishesBuilding);
      pool.release('c');

      expect(pool.contains('a'), isTrue,
          reason: 'Player a was used more recently than player b, so a should stay and b should '
              'be the one dropped');
      expect(pool.contains('b'), isFalse,
          reason: 'Player b has not been used since it was added, so it should now count as the '
              'oldest one and go first');
    });

    test('Should never remove a player that a widget is still showing', () {
      final pool = VideoControllerPool(maxSize: 1);
      pool.acquire('onscreen', neverFinishesBuilding);
      pool.acquire('other', neverFinishesBuilding);

      expect(pool.contains('onscreen'), isTrue,
          reason: 'Closing a player while its widget still uses it crashes playback, so the pool '
              'should go over its size rather than drop a player that is in use');
      expect(pool.contains('other'), isTrue,
          reason: 'The player just asked for is in use as well, so nothing should be dropped and '
              'the pool should stay over its size until one of them is released');
    });
  });

  group('VideoControllerPool.release()', () {
    test('Should keep the player in the pool for later reuse', () {
      final pool = VideoControllerPool(maxSize: 5);
      pool.acquire('tweet:0', neverFinishesBuilding);
      pool.release('tweet:0');

      expect(pool.contains('tweet:0'), isTrue,
          reason: 'This method only says that no widget is showing the video, so the player '
              'should stay cached. Only being dropped from the pool should close it');
    });
  });

  group('VideoControllerPool.invalidate()', () {
    test('Should do nothing while a widget still holds the player', () {
      final pool = VideoControllerPool(maxSize: 5);
      pool.acquire('shared', neverFinishesBuilding);
      pool.acquire('shared', neverFinishesBuilding);
      pool.release('shared');

      pool.invalidate('shared');

      expect(pool.contains('shared'), isTrue,
          reason: 'The same video can be on screen in two places, for example in the feed and in '
              'the open tweet, so one of them closing should leave the other one playing');
    });

    test('Should remove the player once nothing uses it', () {
      final pool = VideoControllerPool(maxSize: 5);
      pool.acquire('stale', neverFinishesBuilding);
      pool.release('stale');

      pool.invalidate('stale');

      expect(pool.contains('stale'), isFalse,
          reason: 'This method exists to force a rebuild, for example after a quality change, so '
              'with no widget left it should really drop the player');
    });
  });

  group('VideoControllerPool.anyVisible()', () {
    test('Should stay true while at least one tile says the key is visible', () {
      final pool = VideoControllerPool();
      final tileA = Object();
      final tileB = Object();

      pool.markVisible('tweet:0', tileA);
      pool.markVisible('tweet:0', tileB);
      pool.markHidden('tweet:0', tileA);

      expect(pool.anyVisible('tweet:0'), isTrue,
          reason: 'The same video shown in two places should stay visible until the last tile '
              'hides, otherwise it stops playing while still on screen');

      pool.markHidden('tweet:0', tileB);
      expect(pool.anyVisible('tweet:0'), isFalse,
          reason: 'The last tile is gone, so the video is really off screen and this should turn '
              'false to let playback stop');
    });
  });

  group('VideoControllerPool.markHidden()', () {
    test('Should do nothing for a key that was never marked visible', () {
      final pool = VideoControllerPool();

      expect(() => pool.markHidden('unknown', Object()), returnsNormally,
          reason: 'Widgets are not removed in a fixed order, so a tile can report hidden after '
              'its key was already cleaned up, and that should be ignored rather than throw');
    });
  });
}
