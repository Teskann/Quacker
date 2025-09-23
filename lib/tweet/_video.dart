import 'package:chewie/chewie.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quacker/generated/l10n.dart';
import 'package:quacker/tweet/_video_controls.dart';
import 'package:quacker/utils/downloads.dart';
import 'package:quacker/utils/iterables.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TweetVideoUrls {
  final String streamUrl;
  final String? downloadUrl;

  TweetVideoUrls(this.streamUrl, this.downloadUrl);
}

class TweetVideoMetadata {
  final double aspectRatio;
  final String imageUrl;
  final Future<TweetVideoUrls> Function() streamUrlsBuilder;

  TweetVideoMetadata(this.aspectRatio, this.imageUrl, this.streamUrlsBuilder);

  factory TweetVideoMetadata.fromMedia(Media media) {
    var aspectRatio = media.videoInfo?.aspectRatio == null
        ? 1.0
        : media.videoInfo!.aspectRatio![0] / media.videoInfo!.aspectRatio![1];

    var variants = media.videoInfo?.variants ?? [];
    var streamUrl = variants[0].url!;
    var imageUrl = media.mediaUrlHttps!;

    // Find the MP4 video with the highest bitrate
    var downloadUrl = variants
        .where((e) => e.bitrate != null)
        .where((e) => e.url != null)
        .where((e) => e.contentType == 'video/mp4')
        .sorted((a, b) => a.bitrate!.compareTo(b.bitrate!))
        .map((e) => e.url)
        .firstWhereOrNull((e) => e != null);

    return TweetVideoMetadata(aspectRatio, imageUrl, () async => TweetVideoUrls(streamUrl, downloadUrl));
  }
}

class TweetVideo extends StatefulWidget {
  final String username;
  final bool loop;
  final TweetVideoMetadata metadata;
  final bool alwaysPlay;
  final bool disableControls;

  const TweetVideo({
    super.key,
    required this.username,
    required this.loop,
    required this.metadata,
    this.alwaysPlay = false,
    this.disableControls = false,
  });

  @override
  State<StatefulWidget> createState() => _TweetVideoState();
}

class _TweetVideoState extends State<TweetVideo> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  Future<void> _loadVideo() async {
    var urls = await widget.metadata.streamUrlsBuilder();
    var streamUrl = urls.streamUrl;
    var downloadUrl = urls.downloadUrl;

    _videoController = VideoPlayerController.networkUrl(Uri.parse(streamUrl));

    var model = context.read<VideoContextState>();
    var volume = model.isMuted ? 0.0 : _videoController!.value.volume;
    _videoController!.setVolume(volume);

    _videoController!.addListener(() {
      model.setIsMuted(_videoController!.value.volume);
    });

    _chewieController = ChewieController(
      aspectRatio: widget.metadata.aspectRatio,
      autoInitialize: true,
      autoPlay: widget.alwaysPlay,
      allowMuting: !widget.disableControls,
      showControls: !widget.disableControls,
      allowedScreenSleep: false,
      customControls: const FritterMaterialControls(),
      additionalOptions: (context) => [
        OptionItem(
          onTap: (BuildContext _) async {
            var video = downloadUrl;
            if (video == null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(L10n.current.download_media_no_url),
              ));
              return;
            }

            var videoUri = Uri.parse(video);
            var fileName = '${widget.username}-${path.basename(videoUri.path)}';

            await downloadUriToPickedFile(
              context,
              videoUri,
              fileName,
              prefs: PrefService.of(context),
              onStart: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(L10n.of(context).downloading_media),
                ));
              },
              onSuccess: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(L10n.of(context).successfully_saved_the_media),
                ));
              },
            );
          },
          iconData: Icons.download,
          title: L10n.of(context).download,
        )
      ],
      looping: widget.loop,
      videoPlayerController: _videoController!,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 42,
              ),
              Text(errorMessage)
            ],
          ),
        );
      },
    );

    _videoController!.addListener(() {
      // Change wake lock screen
      if (_chewieController!.isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _loadVideo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return AspectRatio(
              aspectRatio: widget.metadata.aspectRatio,
              child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _Video(
                      controller: _chewieController!,
                      alwaysPlay: widget.alwaysPlay)),
            );
          }
          return const Center(child: CircularProgressIndicator());
        });
  }

  @override
  void dispose() {
    // TODO: These now seem to get called when the video player goes fullscreen. They shouldn't though
    _videoController?.dispose();
    _chewieController?.dispose();

    WakelockPlus.disable();

    super.dispose();
  }
}

class _Video extends StatefulWidget {
  final ChewieController controller;
  final bool alwaysPlay;

  const _Video({required this.controller, required this.alwaysPlay});

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: UniqueKey(),
      onVisibilityChanged: (info) {
        if (mounted) {
          if (!widget.alwaysPlay && info.visibleFraction == 0 && !widget.controller.isFullScreen) {
            widget.controller.pause();
          }
        }
      },
      child: Chewie(
        controller: widget.controller,
      ),
    );
  }
}

class VideoContextState extends ChangeNotifier {
  bool isMuted;

  VideoContextState(this.isMuted);

  void setIsMuted(double volume) {
    if (isMuted && volume > 0 || !isMuted && volume == 0) {
      isMuted = !isMuted;
    }

    notifyListeners();
  }
}
