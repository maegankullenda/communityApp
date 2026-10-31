/// Wall-clock times are text (`2026-10-06T09:00:00.000`) so 09:00 stays 09:00.
const schemaStatements = <String>[
  '''
CREATE TABLE IF NOT EXISTS accounts (
  id text PRIMARY KEY,
  email text NOT NULL UNIQUE,
  display_name text NOT NULL,
  role text NOT NULL CHECK (role IN ('customer', 'provider')),
  provider_id text,
  password_hash text NOT NULL
)
''',
  '''
ALTER TABLE accounts DROP CONSTRAINT IF EXISTS accounts_role_check
''',
  '''
ALTER TABLE accounts
ADD CONSTRAINT accounts_role_check
CHECK (role IN ('customer', 'provider', 'admin'))
''',
  '''
CREATE TABLE IF NOT EXISTS sessions (
  token text PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts (id),
  created_at text NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS services (
  id text PRIMARY KEY,
  name text NOT NULL UNIQUE,
  summary text NOT NULL,
  fulfillment text NOT NULL CHECK (fulfillment IN ('appointment', 'order')),
  position integer NOT NULL
)
''',
  '''
ALTER TABLE services
ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true
''',
  '''
CREATE TABLE IF NOT EXISTS providers (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  bio text NOT NULL
)
''',
  '''
ALTER TABLE providers
ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true
''',
  '''
CREATE TABLE IF NOT EXISTS provider_services (
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  active boolean NOT NULL DEFAULT true,
  PRIMARY KEY (provider_id, service_id)
)
''',
  '''
ALTER TABLE provider_services
ADD COLUMN IF NOT EXISTS active boolean NOT NULL DEFAULT true
''',
  '''
CREATE TABLE IF NOT EXISTS customer_profiles (
  account_id text PRIMARY KEY REFERENCES accounts (id),
  first_name text NOT NULL DEFAULT '',
  surname text NOT NULL DEFAULT '',
  address text NOT NULL,
  contact_number text NOT NULL
)
''',
  '''
ALTER TABLE customer_profiles
ADD COLUMN IF NOT EXISTS first_name text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE customer_profiles
ADD COLUMN IF NOT EXISTS surname text NOT NULL DEFAULT ''
''',
  '''
CREATE TABLE IF NOT EXISTS vehicles (
  id text PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts (id),
  name text NOT NULL,
  vehicle_type text NOT NULL CHECK (vehicle_type IN ('hatch', 'sedan', 'suv')),
  registration text NOT NULL DEFAULT '',
  position integer NOT NULL
)
''',
  '''
ALTER TABLE vehicles
ADD COLUMN IF NOT EXISTS registration text NOT NULL DEFAULT ''
''',
  '''
CREATE TABLE IF NOT EXISTS time_slots (
  id text PRIMARY KEY,
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  starts_at text NOT NULL,
  duration_minutes integer NOT NULL,
  capacity integer NOT NULL,
  booked_count integer NOT NULL DEFAULT 0 CHECK (booked_count >= 0)
)
''',
  '''
CREATE TABLE IF NOT EXISTS appointments (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts (id),
  slot_id text NOT NULL REFERENCES time_slots (id),
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  starts_at text NOT NULL,
  duration_minutes integer NOT NULL,
  status text NOT NULL CHECK (
    status IN ('booked', 'pending', 'declined', 'cancelled')
  ),
  vehicle_label text,
  price_cents integer,
  vehicle_ids text NOT NULL DEFAULT '',
  wash_id text,
  wash_name text,
  vehicle_washes text NOT NULL DEFAULT '',
  decline_message text NOT NULL DEFAULT '',
  suggested_from text,
  suggested_until text
)
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS vehicle_ids text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS wash_id text
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS wash_name text
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS vehicle_washes text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS decline_message text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS suggested_from text
''',
  '''
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS suggested_until text
''',
  '''
CREATE TABLE IF NOT EXISTS wash_options (
  id text PRIMARY KEY,
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  duration_minutes integer NOT NULL,
  price_cents integer NOT NULL,
  hatch_duration_minutes integer,
  hatch_price_cents integer,
  sedan_duration_minutes integer,
  sedan_price_cents integer,
  suv_duration_minutes integer,
  suv_price_cents integer,
  position integer NOT NULL
)
''',
  '''
ALTER TABLE wash_options
ADD COLUMN IF NOT EXISTS description text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS hatch_duration_minutes integer
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS hatch_price_cents integer
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS sedan_duration_minutes integer
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS sedan_price_cents integer
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS suv_duration_minutes integer
''',
  '''
ALTER TABLE wash_options ADD COLUMN IF NOT EXISTS suv_price_cents integer
''',
  '''
DROP INDEX IF EXISTS one_active_booking_per_user_slot
''',
  '''
CREATE UNIQUE INDEX IF NOT EXISTS one_active_booking_per_user_slot
ON appointments (user_id, slot_id)
WHERE status IN ('booked', 'pending')
''',
  '''
ALTER TABLE appointments DROP CONSTRAINT IF EXISTS appointments_status_check
''',
  '''
ALTER TABLE appointments
ADD CONSTRAINT appointments_status_check
CHECK (status IN ('booked', 'pending', 'declined', 'cancelled'))
''',
  '''
CREATE TABLE IF NOT EXISTS menu_items (
  id text PRIMARY KEY,
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  name text NOT NULL,
  description text NOT NULL,
  price_cents integer NOT NULL,
  available_from text NOT NULL,
  available_until text NOT NULL
)
''',
  '''
CREATE TABLE IF NOT EXISTS orders (
  id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES accounts (id),
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  placed_at text NOT NULL,
  status text NOT NULL CHECK (status IN ('placed', 'cancelled'))
)
''',
  '''
CREATE TABLE IF NOT EXISTS order_lines (
  order_id text NOT NULL REFERENCES orders (id),
  position integer NOT NULL,
  item_id text NOT NULL,
  name text NOT NULL,
  quantity integer NOT NULL,
  unit_price_cents integer NOT NULL,
  PRIMARY KEY (order_id, position)
)
''',
  '''
CREATE TABLE IF NOT EXISTS offerings (
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  open_hours text NOT NULL DEFAULT '',
  open_weekdays text NOT NULL DEFAULT '',
  weekday_hours text NOT NULL DEFAULT '',
  weekend_hours text NOT NULL DEFAULT '',
  advance_amount integer NOT NULL DEFAULT 0,
  advance_unit text NOT NULL DEFAULT 'hour',
  open_for_amount integer NOT NULL DEFAULT 1,
  open_for_unit text NOT NULL DEFAULT 'week',
  auto_confirm boolean NOT NULL DEFAULT true,
  concurrent_bookings integer NOT NULL DEFAULT 1,
  PRIMARY KEY (provider_id, service_id)
)
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS open_weekdays text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS weekday_hours text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS weekend_hours text NOT NULL DEFAULT ''
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS advance_amount integer NOT NULL DEFAULT 0
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS advance_unit text NOT NULL DEFAULT 'hour'
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS open_for_amount integer NOT NULL DEFAULT 1
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS open_for_unit text NOT NULL DEFAULT 'week'
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS auto_confirm boolean NOT NULL DEFAULT true
''',
  '''
ALTER TABLE offerings
ADD COLUMN IF NOT EXISTS concurrent_bookings integer NOT NULL DEFAULT 1
''',
  '''
CREATE TABLE IF NOT EXISTS treatments (
  id text PRIMARY KEY,
  provider_id text NOT NULL REFERENCES providers (id),
  service_id text NOT NULL REFERENCES services (id),
  name text NOT NULL,
  description text NOT NULL DEFAULT '',
  duration_minutes integer NOT NULL,
  price_cents integer NOT NULL,
  position integer NOT NULL
)
''',
  '''
CREATE INDEX IF NOT EXISTS slots_by_service_and_start
ON time_slots (service_id, provider_id, starts_at)
''',
  '''
CREATE TABLE IF NOT EXISTS notifications (
  id text PRIMARY KEY,
  account_id text NOT NULL REFERENCES accounts (id),
  appointment_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('requested', 'confirmed', 'declined')),
  message text NOT NULL,
  created_at text NOT NULL,
  visible_until text,
  read boolean NOT NULL DEFAULT false
)
''',
  '''
ALTER TABLE notifications
ADD COLUMN IF NOT EXISTS visible_until text
''',
  '''
UPDATE notifications AS n
SET visible_until = a.starts_at
FROM appointments AS a
WHERE n.appointment_id = a.id
  AND n.kind IN ('confirmed', 'declined')
  AND n.visible_until IS NULL
''',
  '''
CREATE INDEX IF NOT EXISTS notifications_by_account
ON notifications (account_id, created_at)
''',
];
