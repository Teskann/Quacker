import 'package:quax/database/entities.dart';

/// The longest query X reads for one search.
const _maxQueryLength = 512;

/// Builds the X search query used to load one chunk of a feed or group.
String buildFeedSearchQuery(
  List<Subscription> subscriptions, {
  required bool includeReplies,
  required bool includeRetweets,
}) {
  final subscriptionsQuery = subscriptions.map((subscription) => subscription.searchTerm).join(' OR ');

  assert(subscriptionsQuery.length <= _maxQueryLength, 'A chunk should hold few enough subscriptions to fit one query');

  return [
    if (subscriptionsQuery.isNotEmpty) '($subscriptionsQuery)',
    if (!includeReplies) '-filter:replies',
    includeRetweets ? 'include:nativeretweets' : '-filter:retweets',
  ].join(' ');
}
