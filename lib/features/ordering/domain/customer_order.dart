enum OrderStatus { placed, cancelled }

final class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.unitPriceCents,
  });

  final String itemId;
  final String name;
  final int quantity;
  final int unitPriceCents;

  int get lineTotalCents => quantity * unitPriceCents;
}

final class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.userId,
    required this.providerId,
    required this.serviceId,
    required this.lines,
    required this.placedAt,
    this.status = OrderStatus.placed,
  });

  final String id;
  final String userId;
  final String providerId;
  final String serviceId;
  final List<OrderLine> lines;
  final DateTime placedAt;
  final OrderStatus status;

  int get totalCents => lines.fold(0, (sum, line) => sum + line.lineTotalCents);

  bool get isActive => status == OrderStatus.placed;
}
