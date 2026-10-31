import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:community_app/features/identity/domain/account.dart';
import 'package:community_app/presentation/activity_page.dart';
import 'package:community_app/presentation/admin_home_page.dart';
import 'package:community_app/presentation/awaiting_confirmation_page.dart';
import 'package:community_app/presentation/decline_booking_page.dart';
import 'package:community_app/presentation/declined_booking_page.dart';
import 'package:community_app/presentation/create_category_page.dart';
import 'package:community_app/presentation/customer_booking_page.dart';
import 'package:community_app/presentation/configure_offering_page.dart';
import 'package:community_app/presentation/customer_shell.dart';
import 'package:community_app/presentation/dependencies.dart';
import 'package:community_app/presentation/notifications_page.dart';
import 'package:community_app/presentation/offer_service_page.dart';
import 'package:community_app/presentation/profile_page.dart';
import 'package:community_app/presentation/offering_page.dart';
import 'package:community_app/presentation/provider_bookings_page.dart';
import 'package:community_app/presentation/provider_day_page.dart';
import 'package:community_app/presentation/provider_home_page.dart';
import 'package:community_app/presentation/provider_shell.dart';
import 'package:community_app/presentation/providers_page.dart';
import 'package:community_app/presentation/services_page.dart';
import 'package:community_app/presentation/sign_in_page.dart';
import 'package:community_app/presentation/wash_menu_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/services',
    refreshListenable: refresh,
    redirect: (context, state) {
      final account = ref.read(sessionProvider);
      final path = state.uri.path;
      final signingIn = path == '/sign-in';

      if (account == null) {
        return signingIn ? null : '/sign-in';
      }

      final providerArea = path.startsWith('/provider');
      final adminArea = path.startsWith('/admin');
      if (account.role == AccountRole.admin) {
        return adminArea ? null : '/admin';
      }
      if (account.role == AccountRole.provider) {
        return providerArea ? null : '/provider';
      }
      if (signingIn || providerArea || adminArea) {
        return '/services';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CustomerShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/services',
                builder: (context, state) => const ServicesPage(),
                routes: [
                  GoRoute(
                    path: ':serviceId',
                    builder: (context, state) => ProvidersPage(
                      serviceId: state.pathParameters['serviceId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'providers/:providerId',
                        builder: (context, state) => OfferingPage(
                          serviceId: state.pathParameters['serviceId']!,
                          providerId: state.pathParameters['providerId']!,
                          appointmentId:
                              state.uri.queryParameters['appointment'],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (context, state) => const ActivityPage(),
                routes: [
                  GoRoute(
                    path: ':appointmentId',
                    builder: (context, state) => DeclinedBookingPage(
                      appointmentId: state.pathParameters['appointmentId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminHomePage(),
        routes: [
          GoRoute(
            path: 'category',
            builder: (context, state) => const CreateCategoryPage(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ProviderShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider',
                builder: (context, state) => const ProviderHomePage(),
                routes: [
                  GoRoute(
                    path: 'offer',
                    builder: (context, state) => const OfferServicePage(),
                    routes: [
                      GoRoute(
                        path: ':serviceId',
                        builder: (context, state) => ConfigureOfferingPage(
                          serviceId: state.pathParameters['serviceId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'washes/:serviceId',
                    builder: (context, state) => WashMenuPage(
                      serviceId: state.pathParameters['serviceId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/bookings',
                builder: (context, state) => const ProviderBookingsPage(),
                routes: [
                  GoRoute(
                    path: 'awaiting',
                    builder: (context, state) =>
                        const AwaitingConfirmationPage(),
                    routes: [
                      GoRoute(
                        path: ':appointmentId',
                        builder: (context, state) => DeclineBookingPage(
                          appointmentId: state.pathParameters['appointmentId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'booking/:appointmentId',
                    builder: (context, state) => CustomerBookingPage(
                      appointmentId: state.pathParameters['appointmentId']!,
                    ),
                  ),
                  GoRoute(
                    path: ':day',
                    builder: (context, state) {
                      final parts = state.pathParameters['day']!.split('-');
                      return ProviderDayPage(
                        day: DateTime(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                          int.parse(parts[2]),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/profile',
                builder: (context, state) =>
                    const ProfilePage(includeVehicles: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/provider/notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

final class RouterRefresh extends ChangeNotifier {
  RouterRefresh(this._ref) {
    _subscription = _ref.listen(sessionProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
  late final ProviderSubscription<Account?> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
