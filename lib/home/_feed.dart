import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quacker/client/client.dart';
import 'package:quacker/constants.dart';
import 'package:quacker/home/_for_you.dart';
import 'package:quacker/generated/l10n.dart';
import 'package:quacker/group/_settings.dart';
import 'package:quacker/group/group_model.dart';
import 'package:quacker/group/group_screen.dart';

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String id;
  final String name;

  const FeedScreen({super.key, required this.scrollController, required this.id, required this.name});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen>
    with AutomaticKeepAliveClientMixin<FeedScreen>, TickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final PagingController<String?, TweetChain> _pagingController = PagingController(firstPageKey: null);
  late TabController _tabController;
  int _tab = 0;
  Duration animationDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.animation!.addListener(_tabListener);
  }

  void _tabListener() {
    if (_tab != _tabController.animation!.value.round()) {
      setState(() {
        _tab = _tabController.animation!.value.round();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final BasePrefService prefs = PrefService.of(context);
    final bool disableAnimations = prefs.get(optionDisableAnimations) == true;

    return Provider<GroupModel>(create: (context) {
      var model = GroupModel(widget.id);
      model.loadGroup();

      return model;
    }, builder: (context, child) {
      var model = context.read<GroupModel>();
      final l10n = L10n.of(context);

      return NestedScrollView(
          controller: widget.scrollController,
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                pinned: false,
                snap: true,
                floating: true,
                title: DropdownMenu(
                  initialSelection: 0,
                  inputDecorationTheme: InputDecorationTheme(
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  dropdownMenuEntries: [
                    DropdownMenuEntry(value: 0, label: l10n.following),
                    DropdownMenuEntry(value: 1, label: l10n.foryou)
                  ],
                  onSelected: (value) {
                    setState(() => _tab = value!);
                  },
                ),
                actions: [
                  if (_tab == 0)
                    IconButton(icon: const Icon(Icons.more_vert), onPressed: () => showFeedSettings(context, model)),
                  IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () async {
                        if (disableAnimations == false) {
                          await widget.scrollController
                              .animateTo(0, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
                        } else {
                          widget.scrollController.jumpTo(0);
                        }
                      }),
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        if (_tab == 0) {
                          await model.loadGroup();
                        } else {
                          _pagingController.refresh();
                        }
                      }),
                ],
              ),
            ];
          },
          body: [
            SubscriptionGroupScreenContent(
              id: widget.id,
            ),
            ForYouTweets(_pagingController, type: 'profile', includeReplies: false, pref: prefs),
          ][_tab]);
    });
  }
}
