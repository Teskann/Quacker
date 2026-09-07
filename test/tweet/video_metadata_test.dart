import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/_video.dart';

void main() {
  Variant variant(String url, {int? bitrate, String contentType = 'video/mp4'}) => Variant()
    ..url = url
    ..bitrate = bitrate
    ..contentType = contentType;

  Future<TweetVideoUrls> build(List<Variant> variants) =>
      TweetVideoMetadata.streamUrlsBuilderFromVariants(variants)();

  group('TweetVideoMetadata.streamUrlsBuilderFromVariants()', () {
    test('Should list the MP4 files with the highest bitrate first', () async {
      final urls = await build([
        variant('https://video.x.com/master.m3u8', contentType: 'application/x-mpegURL'),
        variant('https://video.x.com/640x360/low.mp4', bitrate: 632000),
        variant('https://video.x.com/1280x720/high.mp4', bitrate: 2176000),
      ]);

      expect(urls.qualities.map((q) => q.label), ['720p', '360p'],
          reason: 'The quality menu should show the best one first and take the name from the '
              'size in the URL. The HLS file should not appear in the menu at all');
      expect(urls.streamUrl, contains('high.mp4'),
          reason: 'Playback should use the MP4 files and not the HLS playlist, because HLS gives '
              'the quality menu nothing to choose from');
    });

    test('Should use the first file when the tweet has no MP4', () async {
      final urls = await build([
        variant('https://video.x.com/master.m3u8',
            bitrate: 0, contentType: 'application/x-mpegURL'),
      ]);

      expect(urls.streamUrl, endsWith('master.m3u8'),
          reason: 'Live videos only ship HLS, which the player can read on its own, so it should '
              'be used rather than nothing');
      expect(urls.qualities, isEmpty,
          reason: 'There is no MP4 to choose from, so the quality menu should stay empty');
      expect(urls.downloadUrl, isNull,
          reason: 'There is no progressive file to save, so no download should be offered');
    });

    test('Should name a quality with its bitrate when the URL has no size in it', () async {
      final urls = await build([variant('https://video.x.com/clip.mp4', bitrate: 2500000)]);

      expect(urls.qualities, hasLength(1),
          reason: 'One MP4 file should give exactly one entry in the quality menu');
      expect(urls.qualities.first.label, '2.5 Mbps',
          reason: 'Not every MP4 URL carries the video size, so the bitrate should be used '
              'instead. Otherwise the quality menu shows an empty name');
    });

    test('Should give no playable URL when the tweet has no video file at all', () async {
      late final Future<TweetVideoUrls> built;
      expect(() => built = build([]), returnsNormally,
          reason: 'TweetVideoMetadata.fromMedia passes `media.videoInfo?.variants ?? []`, so an '
              'empty list is an expected input and should be handled here. Throwing takes the '
              'video widget down instead of showing a tweet with nothing to play');
      await expectLater(built, completes,
          reason: 'Building the URLs should also succeed later on, not only synchronously');

      final urls = await built;
      expect(urls.streamUrl, isEmpty,
          reason: 'There is nothing to play, so the stream URL should be empty and let the player '
              'report the failure through its own error path');
      expect(urls.qualities, isEmpty,
          reason: 'There is no MP4 to choose from, so the quality menu should stay empty');
      expect(urls.downloadUrl, isNull,
          reason: 'There is no progressive file to save, so no download should be offered');
    });

    test('Should give no playable URL when every variant is missing its URL', () async {
      late final Future<TweetVideoUrls> built;
      expect(() => built = build([variant('', contentType: 'application/x-mpegURL')..url = null]),
          returnsNormally,
          reason: 'A variant can arrive without a URL, so it should be skipped rather than read '
              'and turned into a crash');
      await expectLater(built, completes,
          reason: 'Building the URLs should also succeed later on, not only synchronously');

      expect((await built).streamUrl, isEmpty,
          reason: 'No variant carries a URL, so there is nothing to play');
    });
  });
}
