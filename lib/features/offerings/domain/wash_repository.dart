import 'package:community_app/features/offerings/domain/wash_option.dart';

abstract interface class WashRepository {
  Future<List<WashOption>> washesFor({
    required String providerId,
    required String serviceId,
  });

  Future<void> replaceWashes({
    required String providerId,
    required String serviceId,
    required List<WashOption> washes,
  });
}
