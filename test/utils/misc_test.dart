import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/misc.dart';

void main() {
  group('findInJSONArray()', () {
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'fr', 'name': 'French'},
    ];

    test('Should find an item by key and value', () {
      expect(findInJSONArray(languages, 'code', 'fr'), isTrue,
          reason: 'The item is not the first one, so the search should look at the whole array '
              'and not only at the head');
    });

    test('Should not match a value stored under a different key', () {
      expect(findInJSONArray(languages, 'name', 'fr'), isFalse,
          reason: 'The key should be honoured, otherwise a language name could pass for a '
              'language code');
    });

    test('Should return false for an empty array', () {
      expect(findInJSONArray([], 'code', 'en'), isFalse,
          reason: 'An empty list of supported languages means nothing can be translated, so this '
              'should be false and should not throw');
    });
  });

  group('getShortSystemLocale()', () {
    test('Should return a language code with no country part', () {
      expect(getShortSystemLocale(), isNot(contains('_')),
          reason: 'The translation API is queried with a bare language code, so the country half '
              'of a locale like fr_FR should be cut off');
    });
  });
}
