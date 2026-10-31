enum AccountRole { customer, provider, admin }

final class Account {
  const Account({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.providerId,
  });

  final String id;
  final String email;
  final String displayName;
  final AccountRole role;
  final String? providerId;
}
