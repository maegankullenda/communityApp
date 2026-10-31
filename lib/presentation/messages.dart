import 'package:community_app/features/catalog/domain/create_category.dart';
import 'package:community_app/features/identity/domain/auth_repository.dart';
import 'package:community_app/features/offerings/domain/offer_service.dart';
import 'package:community_app/features/offerings/domain/save_wash_menu.dart';
import 'package:community_app/features/ordering/domain/ordering_repository.dart';
import 'package:community_app/features/profile/domain/save_customer_profile.dart';
import 'package:community_app/features/scheduling/domain/scheduling_repository.dart';

String authFailureMessage(AuthFailure failure) {
  return switch (failure) {
    AuthFailure.invalidCredentials => 'Those details do not match our records.',
    AuthFailure.unavailable => 'The community store is not running.',
  };
}

String bookingFailureMessage(BookingFailure failure) {
  return switch (failure) {
    BookingFailure.slotNotFound => 'That time is no longer listed.',
    BookingFailure.slotInThePast => 'That time has already passed.',
    BookingFailure.outsideBookingWindow =>
      'That time is outside this provider\'s booking window.',
    BookingFailure.notOpen => 'That time is not open.',
    BookingFailure.slotFull => 'That time is already booked.',
    BookingFailure.alreadyBooked => 'You already have this time booked.',
    BookingFailure.serviceMismatch =>
      'That time does not belong to this service.',
    BookingFailure.vehicleRequired => 'Choose which vehicle this wash is for.',
    BookingFailure.unknownVehicle => 'That vehicle is not on your profile.',
    BookingFailure.appointmentNotFound => 'That booking is no longer listed.',
    BookingFailure.washRequired => 'Choose a wash for each vehicle.',
    BookingFailure.unknownWash => 'That wash is no longer offered.',
    BookingFailure.treatmentRequired => 'Choose a treatment.',
    BookingFailure.unknownTreatment => 'That treatment is no longer offered.',
    BookingFailure.serviceUnavailable =>
      'This provider is not taking bookings right now.',
    BookingFailure.missingDeclineMessage =>
      'Tell the customer why this time does not work.',
    BookingFailure.invalidSuggestedRange =>
      'Leave both dates empty, or suggest a from date and an until date that is the same day or later.',
  };
}

String washMenuFailureMessage(WashMenuFailure failure) {
  return switch (failure) {
    WashMenuFailure.emptyName => 'Give each wash a name.',
    WashMenuFailure.duplicateName => 'Each wash needs its own name.',
    WashMenuFailure.invalidDuration => 'Choose a duration of 1 to 4 hours.',
    WashMenuFailure.invalidPrice => 'Enter a price in rands for each wash.',
  };
}

String profileFailureMessage(ProfileFailure failure) {
  return switch (failure) {
    ProfileFailure.emptyVehicleName => 'Give each vehicle a name.',
    ProfileFailure.tooManyVehicles => 'You can save up to 5 vehicles.',
    ProfileFailure.invalidContactNumber =>
      'Enter a contact number with 7 to 15 digits.',
  };
}

String orderFailureMessage(OrderFailure failure) {
  return switch (failure) {
    OrderFailure.emptyOrder => 'Add at least one meal.',
    OrderFailure.invalidQuantity =>
      'Each meal needs a quantity of one or more.',
    OrderFailure.unknownItem => 'One of those meals is no longer listed.',
    OrderFailure.itemUnavailable =>
      'One of those meals is outside its available days.',
    OrderFailure.mixedProviders => 'Order from one cook at a time.',
    OrderFailure.serviceMismatch =>
      'That meal does not belong to this service.',
  };
}

String createCategoryFailureMessage(CreateCategoryFailure failure) {
  return switch (failure) {
    CreateCategoryFailure.emptyName => 'Give the category a name.',
    CreateCategoryFailure.duplicateName =>
      'A category with that name already exists.',
  };
}

String offerFailureMessage(OfferFailure failure) {
  return switch (failure) {
    OfferFailure.unknownService => 'That service is no longer listed.',
    OfferFailure.alreadyOffered => 'You already offer this service.',
    OfferFailure.unknownProvider => 'This account cannot publish a service.',
    OfferFailure.missingItem => 'Name the meal you are offering.',
    OfferFailure.invalidPrice => 'Enter a price greater than zero.',
    OfferFailure.missingName => 'Give your service a name.',
    OfferFailure.missingHours => 'Choose at least one open time.',
    OfferFailure.missingTreatment => 'Add at least one treatment.',
    OfferFailure.invalidDuration => 'Choose a duration of 1 to 4 hours.',
    OfferFailure.duplicateTreatment => 'Each treatment needs its own name.',
    OfferFailure.invalidBookingWindow =>
      'Choose a booking window of at least a day and at most a year.',
    OfferFailure.invalidConcurrentBookings =>
      'Enter how many customers can book the same time.',
  };
}
