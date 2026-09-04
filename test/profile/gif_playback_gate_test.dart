import 'package:flutter_test/flutter_test.dart';
import 'package:quax/profile/media_grid/gif_playback_gate.dart';

void main() {
  group('GifPlaybackGate.report()', () {
    test('Should let the most visible tiles play, up to the limit', () {
      final gate = GifPlaybackGate(maxConcurrent: 2);

      gate.report('a', 0.9);
      gate.report('b', 0.5);
      gate.report('c', 0.1);

      expect(gate.isGranted('a'), isTrue,
          reason: 'Tile a is the most visible one, so it should be the first to get a slot');
      expect(gate.isGranted('b'), isTrue,
          reason: 'Tile b is the second most visible one and the limit is 2, so it should get the '
              'other slot');
      expect(gate.isGranted('c'), isFalse,
          reason: 'Each playing tile holds a video player using about 35 MB of memory, so the '
              'limit should hold however many tiles are on screen');
    });

    test('Should pass playback to the next tile when one scrolls away', () {
      final gate = GifPlaybackGate(maxConcurrent: 1);
      gate.report('a', 0.9);
      gate.report('b', 0.5);

      gate.report('a', 0.0);

      expect(gate.isGranted('a'), isFalse,
          reason: 'A visible part of 0 means the tile is off screen, so it should stop being '
              'counted and give up its slot');
      expect(gate.isGranted('b'), isTrue,
          reason: 'The slot that was freed should go to the next most visible tile, otherwise '
              'every GIF ends up stopped after scrolling');
    });

    test('Should keep playback on the same tile when two tiles are equally visible', () {
      final gate = GifPlaybackGate(maxConcurrent: 1);
      gate.report('a', 1.0);
      gate.report('b', 1.0);

      expect(gate.isGranted('a'), isTrue,
          reason: 'A screen full of tiles reports the same visible part on every frame, so the '
              'tile already playing should keep the slot. Without that rule the slot moves back '
              'and forth and every GIF stutters');
      expect(gate.isGranted('b'), isFalse,
          reason: 'Tile b came second with the same visible part, so it should not take the slot');
    });

    test('Should not notify when the set of playing tiles does not change', () {
      final gate = GifPlaybackGate(maxConcurrent: 2);
      gate.report('a', 0.9);

      var notifications = 0;
      gate.addListener(() => notifications++);
      gate.report('a', 0.8);

      expect(notifications, 0,
          reason: 'Tiles report how visible they are on every scroll frame, so a report that '
              'changes nothing should notify nobody. Otherwise the grid rebuilds all the time');
    });

    test('Should notify when the set of playing tiles changes', () {
      final gate = GifPlaybackGate(maxConcurrent: 1);
      gate.report('a', 0.9);

      var notifications = 0;
      gate.addListener(() => notifications++);
      gate.report('b', 1.0);

      expect(notifications, 1,
          reason: 'Tile b takes the slot from tile a, so listeners should be told once for the '
              'grid to rebuild and show the change');
    });
  });

  group('GifPlaybackGate.forget()', () {
    test('Should free the slot of a tile that is forgotten', () {
      final gate = GifPlaybackGate(maxConcurrent: 1);
      gate.report('a', 0.9);
      gate.report('b', 0.5);

      gate.forget('a');

      expect(gate.isGranted('a'), isFalse,
          reason: 'A tile that is gone should not be counted as playing any more');
      expect(gate.isGranted('b'), isTrue,
          reason: 'This method is called when a tile is removed, so the removed tile should hand '
              'its slot to the next one instead of holding it');
    });
  });
}
