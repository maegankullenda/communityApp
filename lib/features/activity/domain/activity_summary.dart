import 'package:community_app/features/ordering/domain/customer_order.dart';
import 'package:community_app/features/scheduling/domain/appointment.dart';

final class AppointmentSummary {
  const AppointmentSummary({
    required this.appointment,
    required this.serviceName,
    required this.providerName,
  });

  final Appointment appointment;
  final String serviceName;
  final String providerName;
}

final class OrderSummary {
  const OrderSummary({
    required this.order,
    required this.serviceName,
    required this.providerName,
  });

  final CustomerOrder order;
  final String serviceName;
  final String providerName;
}

final class MyActivity {
  const MyActivity({required this.appointments, required this.orders});

  final List<AppointmentSummary> appointments;
  final List<OrderSummary> orders;
}

final class ProviderBooking {
  const ProviderBooking({
    required this.appointment,
    required this.serviceName,
    required this.customerName,
    this.customerFirstName = '',
    this.customerSurname = '',
    this.contactNumber = '',
    this.address = '',
  });

  final Appointment appointment;
  final String serviceName;
  final String customerName;
  final String customerFirstName;
  final String customerSurname;
  final String contactNumber;
  final String address;
}
