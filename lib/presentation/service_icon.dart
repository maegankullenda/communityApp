import 'package:flutter/material.dart';

IconData iconForService(String serviceId) {
  return switch (serviceId) {
    'car-wash' => Icons.local_car_wash_outlined,
    'foodie' => Icons.restaurant_outlined,
    'beauty' => Icons.spa_outlined,
    _ => Icons.storefront_outlined,
  };
}
