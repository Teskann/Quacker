import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/article/article_entities.dart';
import 'package:quax/article/entity_map_parser.dart';

void main() {
  Map<String, dynamic> entity(String key, String type, Map<String, dynamic> data) => {
        'key': key,
        'value': {'type': type, 'data': data}
      };

  Map<int, EntityValue> parse(Object entityMap, {List<dynamic> media = const []}) =>
      EntityMapParser.parse(entityMap, media, '1729', 'dogs');

  group('EntityMapParser.parse()', () {
    test('Should read the entity types that are not media, using their key as a number', () {
      final result = parse({
        'entityMap': [
          entity('0', 'MARKDOWN', {'markdown': '**bold**'}),
          entity('1', 'LINK', {'url': 'https://example.org'}),
          entity('2', 'DIVIDER', {}),
        ]
      });

      expect(result.keys, containsAll([0, 1, 2]),
          reason: 'Keys arrive as text but index into the article by number, so each one should '
              'be parsed rather than dropped');
      expect(result[0], isA<MarkdownEntity>(),
          reason: 'The type field should decide which entity is built, and MARKDOWN holds a code '
              'block');
      expect(result[1], isA<LinkEntity>(),
          reason: 'A LINK entity is what makes the text tappable, so this type should build one');
      expect(result[2], isA<DividerEntity>(),
          reason: 'DIVIDER carries no data at all, so an empty data object should still build an '
              'entity rather than be skipped');
    });

    test('Should read an entity map that is still a JSON string', () {
      final result = parse(jsonEncode({
        'entityMap': [
          entity('0', 'MARKDOWN', {'markdown': 'hi'})
        ]
      }));

      expect(result[0], isA<MarkdownEntity>(),
          reason: 'X sends this field as a JSON string for some articles and as a normal object '
              'for others, so both forms should be accepted');
    });

    test('Should return an empty map when the value is neither a list nor an object', () {
      expect(parse('"just a string"'), isEmpty,
          reason: 'An entity map we cannot read should give an article with no entities, rather '
              'than take the whole article screen down');
    });

    test('Should skip a broken entry and keep the other ones', () {
      final result = parse({
        'entityMap': [
          {'key': 'not-a-number', 'value': {}},
          entity('1', 'LINK', {'url': 'https://example.org'}),
        ]
      });

      expect(result.keys, [1],
          reason: 'One broken entity should not cost the reader every other entity of the '
              'article. Only the broken one should be dropped, and the good one should keep its '
              'own key');
    });

    test('Should skip a media entity whose id is not in the tweet media list', () {
      late final Map<int, EntityValue> result;
      expect(
          () => result = parse({
                'entityMap': [
                  entity('0', 'MEDIA', {
                    'mediaItems': [
                      {'mediaId': 'absent'}
                    ]
                  }),
                  entity('1', 'LINK', {'url': 'https://example.org'}),
                ]
              }, media: [
                {'media_id': 'present', 'media_info': {}}
              ]),
          returnsNormally,
          reason: 'An article can name a media id the tweet does not carry, so that entity should '
              'be skipped like any other entry that cannot be read. Throwing stops the whole '
              'article from opening over one missing image');

      expect(result.containsKey(0), isFalse,
          reason: 'A media entity we cannot resolve should be left out of the result');
      expect(result[1], isA<LinkEntity>(),
          reason: 'The entities after the one we cannot read should still be parsed');
    });
  });
}
