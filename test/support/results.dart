import 'package:flutter_test/flutter_test.dart';

import 'package:community_app/core/result.dart';

T successValue<T, E>(Result<T, E> result) {
  return switch (result) {
    Success(:final value) => value,
    Err(:final error) => fail('Expected success but got $error'),
  };
}

E failureError<T, E>(Result<T, E> result) {
  return switch (result) {
    Success(:final value) => fail('Expected failure but got $value'),
    Err(:final error) => error,
  };
}
