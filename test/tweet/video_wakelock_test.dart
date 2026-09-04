import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/video_wakelock.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelock extends WakelockPlusPlatformInterface {
  final List<bool> toggles = [];

  bool get isEnabled => toggles.isNotEmpty && toggles.last;

  @override
  Future<void> toggle({required bool enable}) async => toggles.add(enable);

  @override
  Future<bool> get enabled async => isEnabled;
}

void main() {
  late _FakeWakelock wakelock;

  setUp(() {
    wakelock = _FakeWakelock();
    wakelockPlusPlatformInstance = wakelock;
  });

  // The two media kinds as they are built in _media.dart.
  TweetVideo tweetMedia({required bool isGif}) => TweetVideo(
        username: 'quax',
        metadata: TweetVideoMetadata(1.0, null, () async => TweetVideoUrls('', null)),
        loop: isGif,
        alwaysPlay: isGif,
        disableControls: isGif,
      );

  group('TweetVideo.keepsScreenAwake', () {
    test('Should keep the screen awake for a video', () {
      expect(tweetMedia(isGif: false).keepsScreenAwake, isTrue,
          reason: 'Watching a video without touching the device must not let it dim: that is the '
              'whole point of holding the wakelock');
    });

    test('Should let the screen sleep for a GIF', () {
      expect(tweetMedia(isGif: true).keepsScreenAwake, isFalse,
          reason: 'GIFs play on their own, silently and on a loop, all over the timeline. Keeping '
              'the screen on for them would mean it never sleeps as long as one is on screen');
    });
  });

  group('VideoWakelock.acquire()', () {
    test('Should keep the screen awake while a video plays', () {
      final video = Object();
      VideoWakelock.acquire(video);

      expect(wakelock.isEnabled, isTrue, reason: 'A video is playing, so the screen has to stay on');

      VideoWakelock.release(video);
    });

    test('Should do nothing when the same video acquires twice', () {
      final video = Object();
      VideoWakelock.acquire(video);
      VideoWakelock.acquire(video);

      expect(wakelock.toggles, [true],
          reason: 'The player posts a play event again on a resume or on the way back from '
              'fullscreen, and that is the same video, not a second one');

      VideoWakelock.release(video);

      expect(wakelock.isEnabled, isFalse,
          reason: 'One release has to undo any number of acquires from the same video, otherwise '
              'the screen would stay on for good once it stops');
    });
  });

  group('VideoWakelock.release()', () {
    test('Should keep the screen awake until the last video releases it', () {
      final watched = Object();
      final scrolledPast = Object();
      VideoWakelock.acquire(watched);
      VideoWakelock.acquire(scrolledPast);

      VideoWakelock.release(scrolledPast);

      expect(wakelock.isEnabled, isTrue,
          reason: 'The wakelock is a single process-wide switch. A second video being paused by '
              'the single-audible-video policy, finishing or being disposed by a scroll must not '
              'let the screen sleep on the video the user is actually watching');

      VideoWakelock.release(watched);

      expect(wakelock.isEnabled, isFalse, reason: 'The last holder let go, so nothing is playing');
    });

    test('Should do nothing when the same video releases twice', () {
      final video = Object();
      VideoWakelock.acquire(video);
      VideoWakelock.release(video);
      VideoWakelock.release(video);

      expect(wakelock.toggles, [true, false],
          reason: 'A video that stops is released from several places (pause, dispose, a restart '
              'after an error), and those overlap. Every release past the first is not this '
              'video letting go again, so it must change nothing');
    });

    test('Should ignore a release from a video that never held it', () {
      final playing = Object();
      VideoWakelock.acquire(playing);

      VideoWakelock.release(Object());

      expect(wakelock.isEnabled, isTrue,
          reason: 'A GIF, or a player that never started, gets released on dispose too, and that '
              'must not turn off a wakelock it never acquired');

      VideoWakelock.release(playing);
    });
  });

  group('VideoWakelock.reapply()', () {
    test('Should restore the wakelock after it was disabled from the outside', () async {
      final video = Object();
      VideoWakelock.acquire(video);

      // What better_player does on its way out of fullscreen, even though
      // playback carries on inline.
      await WakelockPlus.disable();
      VideoWakelock.reapply();

      expect(wakelock.isEnabled, isTrue,
          reason: 'The video is still playing after leaving fullscreen, so the screen must stay '
              'on. Nothing else would turn it back on: no new play event is emitted');

      VideoWakelock.release(video);
    });
  });
}
