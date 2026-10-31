enum FulfillmentKind { appointment, order }

final class CommunityService {
  const CommunityService({
    required this.id,
    required this.name,
    required this.summary,
    required this.fulfillment,
    this.active = true,
  });

  final String id;
  final String name;
  final String summary;
  final FulfillmentKind fulfillment;
  final bool active;

  CommunityService withActive(bool active) {
    return CommunityService(
      id: id,
      name: name,
      summary: summary,
      fulfillment: fulfillment,
      active: active,
    );
  }
}
