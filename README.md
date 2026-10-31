# Community

Customers book local services. Providers publish appointment times and meals.

## Run on a simulator

The app targets iOS and Android. Start a simulator before `flutter run`, or Flutter reports that no supported device is connected.

List the simulators on this machine:

```bash
flutter emulators
```

Start the iOS Simulator and the Pixel 6 Android emulator:

```bash
flutter emulators --launch apple_ios_simulator
flutter emulators --launch Pixel_6
```

Wait until both show up, then copy the device id you want:

```bash
flutter devices
```

Run on one device at a time. Use a second terminal for the other device.

```bash
flutter run -d <device-id>
```

Example ids from a local session:

```bash
flutter run -d emulator-5554
flutter run -d 74C97CDA-9642-4174-A39D-C60D94594CD3
```

Those ids change. Prefer the ids printed by `flutter devices`.

Other Android images on this machine are `Medium_Phone_API_36` and `Pixel_9_Pro`. Launch one the same way:

```bash
flutter emulators --launch Pixel_9_Pro
```

## Save data in Postgres

Profiles, bookings, meals, and provider offerings are stored in Postgres. The phone talks to a small API on your computer, and that API is the only process that opens the database. Tests still use the in-memory store and do not need Docker.

Start the database, then the API, then the app:

```bash
docker compose up -d
cd server
dart pub get
dart run bin/server.dart
```

Leave the API running. In another terminal, run the app as usual:

```bash
flutter run -d <device-id>
```

The iOS Simulator uses `http://127.0.0.1:8080`. The Android emulator uses `http://10.0.2.2:8080`. A phone on the same Wi-Fi needs your computer's address:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=http://192.168.1.20:8080
```

Demo accounts are created the first time the API starts, and only when the database is empty. Later restarts keep what you saved. The database password is for the local API only. Account passwords are stored as hashes.

Stop the database with `docker compose stop`. The data stays in the `community_pg` volume. `docker compose down -v` deletes that volume.

## Sign in

Every demo account uses the password `community`.

| Account | Email |
|---|---|
| Alex, customer | `alex@community.app` |
| Sam, car wash | `sam@community.app` |
| Jess, foodie | `jess@community.app` |
| Riley, beauty | `riley@community.app` |
| Maegan, car wash | `maegan@community.app` |
