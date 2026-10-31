final class ServiceProvider {
  const ServiceProvider({
    required this.id,
    required this.displayName,
    required this.bio,
    required this.serviceIds,
    this.inactiveServiceIds = const {},
    this.active = true,
  });

  final String id;
  final String displayName;
  final String bio;
  final Set<String> serviceIds;
  final Set<String> inactiveServiceIds;
  final bool active;

  bool isActive(String serviceId) {
    return active &&
        serviceIds.contains(serviceId) &&
        !inactiveServiceIds.contains(serviceId);
  }

  ServiceProvider withService(String serviceId) {
    return ServiceProvider(
      id: id,
      displayName: displayName,
      bio: bio,
      serviceIds: {...serviceIds, serviceId},
      inactiveServiceIds: inactiveServiceIds,
      active: active,
    );
  }

  ServiceProvider withoutService(String serviceId) {
    return ServiceProvider(
      id: id,
      displayName: displayName,
      bio: bio,
      serviceIds: {...serviceIds}..remove(serviceId),
      inactiveServiceIds: {...inactiveServiceIds}..remove(serviceId),
      active: active,
    );
  }

  ServiceProvider withServiceActive(String serviceId, bool active) {
    final inactive = {...inactiveServiceIds};
    if (active) {
      inactive.remove(serviceId);
    } else {
      inactive.add(serviceId);
    }
    return ServiceProvider(
      id: id,
      displayName: displayName,
      bio: bio,
      serviceIds: serviceIds,
      inactiveServiceIds: inactive,
      active: this.active,
    );
  }

  ServiceProvider withActive(bool active) {
    return ServiceProvider(
      id: id,
      displayName: displayName,
      bio: bio,
      serviceIds: serviceIds,
      inactiveServiceIds: inactiveServiceIds,
      active: active,
    );
  }
}
