import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/x_client_transaction_id/cubic_curve.dart';
import 'package:quax/client/x_client_transaction_id/interpolate.dart';
import 'package:quax/client/x_client_transaction_id/rotation.dart';
import 'package:quax/client/x_client_transaction_id/utils.dart';

void main() {
  group('jsRound()', () {
    test('Should round a half up instead of to the nearest even number', () {
      expect(jsRound(2.5), 3,
          reason: 'JS Math.round(2.5) is 3. Rounding to the nearest even number would give 2 and '
              'change every frame time, which makes the x-client-transaction-id wrong');
      expect(jsRound(3.5), 4,
          reason: 'A half should always go up, whatever the whole part is');
    });

    test('Should round down below a half', () {
      expect(jsRound(2.49), 2, reason: 'Anything under .5 should go down to the whole part');
    });

    test('Should leave a whole number unchanged', () {
      expect(jsRound(7.0), 7, reason: 'A value with no fraction should stay the same');
    });

    test('Should round a negative half towards zero, not away from it', () {
      expect(jsRound(-2.5), -2,
          reason: 'JS Math.round(-2.5) is -2 because a half always goes up. Dart round() would '
              'give -3, and the transaction id has to follow JS');
    });
  });

  group('roundTo2()', () {
    test('Should keep two decimal places', () {
      expect(roundTo2(3.14159), 3.14,
          reason: 'The transaction key stores matrix values at 2 decimals, so anything after the '
              'second one should be dropped');
    });

    test('Should round a half away from zero for both signs', () {
      expect(roundTo2(1.005000001), 1.01, reason: 'A value above the half should go up');
      expect(roundTo2(-1.567), -1.57,
          reason: 'A negative value should go away from zero, not towards it');
    });
  });

  group('isOdd()', () {
    test('Should return -1.0 for an odd number and 0.0 for an even one', () {
      expect(isOdd(3), -1.0, reason: 'Odd indexes should start their range at -1.0');
      expect(isOdd(4), 0.0, reason: 'Even indexes should start their range at 0.0');
      expect(isOdd(0), 0.0,
          reason: 'Zero is even, so the first curve value should start at 0.0');
    });
  });

  group('floatToHex()', () {
    test('Should encode a whole number', () {
      expect(floatToHex(255.0), 'FF', reason: 'Digits above 9 should use upper case A to F');
      expect(floatToHex(10.0), 'A',
          reason: 'The number 10 fits in one hex digit, so there should be no second digit and '
              'no dot');
    });

    test('Should encode the fraction after a dot', () {
      expect(floatToHex(2.75), '2.C',
          reason: '0.75 is 12/16, so the first hex digit after the dot should be C');
    });

    test('Should not add a leading zero when the whole part is zero', () {
      expect(floatToHex(0.5), '.8',
          reason: '_animate adds the leading "0" itself when the result starts with a dot, so '
              'adding one here would give "00.8"');
    });

    test('Should return an empty string for zero', () {
      expect(floatToHex(0.0), '',
          reason: '_animate turns an empty result into "0", so returning "0" here would add an '
              'extra digit to the key');
    });
  });

  final straightLine = Cubic([0.0, 0.0, 1.0, 1.0]);

  group('Cubic.getValue()', () {
    test('Should return the input when the curve is a straight line', () {
      expect(straightLine.getValue(0.5), closeTo(0.5, 1e-4),
          reason: 'Both control points are on the diagonal, so the output should follow the input');
      expect(straightLine.getValue(0.25), closeTo(0.25, 1e-4),
          reason: 'A point away from the middle should match too, otherwise the search inside '
              'getValue only happens to land right at 0.5');
    });

    test('Should return 0 at 0 and 1 at 1', () {
      expect(straightLine.getValue(0.0), closeTo(0.0, 1e-9), reason: 'A curve should start at 0');
      expect(straightLine.getValue(1.0), closeTo(1.0, 1e-9), reason: 'A curve should end at 1');
    });

    test('Should keep going in a straight line outside 0 to 1', () {
      expect(straightLine.getValue(-0.5), lessThan(0.0),
          reason: 'Below 0 the curve should follow its start slope instead of stopping at 0');
      expect(straightLine.getValue(1.5), greaterThan(1.0),
          reason: 'Above 1 the curve should follow its end slope instead of stopping at 1');
    });

    test('Should never go down as the input goes up', () {
      final samples = List.generate(11, (i) => straightLine.getValue(i / 10));
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]),
            reason: 'A curve whose control points only go up should not turn back. A drop at '
                't=${i / 10} means the search inside getValue found the wrong point');
      }
    });
  });

  group('Cubic.calculate()', () {
    test('Should start at 0 and end at 1 for any control points', () {
      expect(Cubic.calculate(0.42, 0.58, 0.0), 0.0,
          reason: 'A bezier should always start at 0, whatever its control points are');
      expect(Cubic.calculate(0.42, 0.58, 1.0), closeTo(1.0, 1e-12),
          reason: 'A bezier should always end at 1, whatever its control points are');
    });
  });

  group('interpolate()', () {
    test('Should return the start list at 0 and the end list at 1', () {
      expect(interpolate([0.0, 10.0], [100.0, 20.0], 0.0), [0.0, 10.0],
          reason: 'At 0 the result should be the start list, with no part of the end list in it');
      expect(interpolate([0.0, 10.0], [100.0, 20.0], 1.0), [100.0, 20.0],
          reason: 'At 1 the result should be the end list, with no part of the start list left');
    });

    test('Should mix each value on its own in the middle', () {
      expect(interpolate([0.0, 10.0], [100.0, 20.0], 0.5), [50.0, 15.0],
          reason: 'Each value should be mixed on its own, not with a single shared number');
    });

    test('Should throw when the two lists have different lengths', () {
      expect(() => interpolate([0.0], [1.0, 2.0], 0.5), throwsArgumentError,
          reason: 'Different lengths mean the caller passed the wrong colour and rotation lists. '
              'Cutting the longer one would build a key that looks right but is wrong');
    });
  });

  group('convertRotationToMatrix()', () {
    test('Should return the identity matrix for no rotation', () {
      expect(convertRotationToMatrix(0), [1.0, -0.0, 0.0, 1.0],
          reason: '0 degrees should not rotate anything');
    });

    test('Should rotate by a quarter turn', () {
      final matrix = convertRotationToMatrix(90);

      expect(matrix, hasLength(4),
          reason: 'A 2x2 matrix should come back flattened to four values');
      expect(matrix[0], closeTo(0.0, 1e-12),
          reason: 'The first value should be the cosine, which is 0 at a quarter turn');
      expect(matrix[1], closeTo(-1.0, 1e-12),
          reason: 'The second value should be minus the sine, which is -1 at a quarter turn');
      expect(matrix[2], closeTo(1.0, 1e-12),
          reason: 'The third value should be the sine, which is 1 at a quarter turn');
      expect(matrix[3], closeTo(0.0, 1e-12),
          reason: 'The fourth value should be the cosine again, so it should match the first one');
    });

    test('Should read its argument as degrees, not radians', () {
      final matrix = convertRotationToMatrix(180);

      expect(matrix, hasLength(4),
          reason: 'A 2x2 matrix should come back flattened to four values');
      expect(matrix[0], closeTo(-1.0, 1e-12),
          reason: 'The cosine of 180 degrees is -1. Reading the argument as radians would give '
              '${cos(180)}');
    });
  });
}
