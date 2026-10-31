import 'package:community_app/core/result.dart';
import 'package:community_app/features/offerings/domain/offering_repository.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';
import 'package:community_app/features/scheduling/domain/wash_quote.dart';

Future<Result<WashQuote?, BookingFailure>> loadTreatmentQuote({
  required OfferingRepository offerings,
  required String providerId,
  required String serviceId,
  String? treatmentId,
}) async {
  final treatments = await offerings.treatmentsFor(
    providerId: providerId,
    serviceId: serviceId,
  );
  if (treatments.isEmpty) {
    return const Success(null);
  }
  for (final treatment in treatments) {
    if (treatment.id == treatmentId) {
      return Success(
        WashQuote(
          priceCents: treatment.priceCents,
          duration: treatment.duration,
          washId: treatment.id,
          washName: treatment.name,
          vehicleWashes: const {},
        ),
      );
    }
  }
  if (treatmentId == null || treatmentId.isEmpty) {
    return const Err(BookingFailure.treatmentRequired);
  }
  return const Err(BookingFailure.unknownTreatment);
}
