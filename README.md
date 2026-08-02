# NUCLEI TECH — Live SCADA & Ticket Management

**Release:** 2.1.0 Blue & White

A multiplatform Flutter application and PHP/MySQL backend for monitoring solar plants, viewing inverter/VCB data, raising issues with images, and managing the complete NUCLEI TECH support workflow.

## Included folders

```text
NUCLEI_TECH_SCADA_TICKETING/
├── frontend/                  Flutter Android/iOS/Web/Windows source
├── backend/                   PHP REST API, image uploads and SMTP email
├── database/                  MySQL schema and sample SCADA JSON
└── README.md
```

## Configured company accounts

| Account | Email | Password | Access |
|---|---|---|---|
| Vijayanth Admin | `vijayanth@scada.com` | `vijayanth@123` | Four Vijayanth plants |
| Vinoba Solar Admin | `vinobasolar@scada.com` | `vinoba@123` | Three Vinoba Solar plants |
| NUCLEI TECH Owner | `nfo.nucleitech@gmail.com` | `Admin@123` | Every plant, ticket, image, history and resolution action |

Change the owner password immediately after the first production deployment. The seed script supports environment-variable overrides.

## Exact plant and SCADA mapping

### Vijayanth

| Display plant | Ticket short ID | Display capacity | SCADA subscription ID |
|---|---|---:|---|
| SRI Ram Nallamani Blue Metals | `SRN` | 1 MW | `via-4mw` |
| Vijayanth Cosmic Powers Pvt Ltd | `VCP` | 7 MW | `via7mw` |
| Krishna Poultry Farm | `KPF` | 3 MW | `via3mw` |
| Bojaraj Textiles Pvt Ltd | `BTJ` | 4 MW | `via-1mw` |

The four values above are stored and transmitted exactly without spaces. The typed `via 3mw` value is implemented as `via3mw`.

### Vinoba Solar

| Display plant | Ticket short ID | SCADA subscription ID |
|---|---|---|
| Anushyam Solar Pvt Ltd | `ANU` | `anushyam` |
| MakkalPower Pvt Ltd | `MAK` | `Makkalpower` |
| Vinoba Solar Pvt Ltd | `VSP` | `vinoba-velliyanai` |

Ticket numbers are generated per plant with the short ID and a local sequence,
for example `NT-SRN-01`, `NT-SRN-02`, then `NT-VCP-01` for a different plant.

All seven plants are configured with:

```text
wss://vinobasolar.scadahub.in:5001
```


## Blue-and-white application design

- Pure white page background across login, dashboards, SCADA views and tickets
- NUCLEI TECH blue application headers with white titles and navigation icons
- Blue primary actions for sign-in, ticket creation, status updates and replies
- White information cards with light-blue borders
- Light-blue input backgrounds and strong blue focus states
- Responsive sign-in layout for phone, tablet, web and Windows
- Responsive plant and SCADA metric grids

## App workflow

1. A company administrator signs in.
2. The administrator sees only that company’s plants.
3. Selecting a plant opens four tabs: Overview, Inverters, VCB and Tickets.
4. The app obtains the WebSocket URL and SCADA site ID from the secured PHP API.
5. The app connects, subscribes, normalizes common SCADA JSON shapes, reconnects automatically, and stores recent snapshots.
6. A user raises a ticket with category, priority, issue details and up to six images.
7. The NUCLEI TECH owner receives an in-app notification and an email at `nfo.nucleitech@gmail.com`.
8. The owner updates the ticket to Assigned, In Progress, Waiting for User, Resolved or Closed.
9. The customer receives an in-app notification and SMTP email automatically.
10. Ticket lists, details, history and notifications refresh every 15 seconds while the app is open.

## Important WebSocket protocol setting

The URL and all site IDs are configured. The server’s exact subscription command and live payload schema were not publicly available for verification. The default subscription message is:

```json
{
  "action": "subscribe",
  "siteId": "{{site_id}}"
}
```

It is stored per plant in the `plants.subscription_payload` JSON column. If the SCADA server expects another command, update that JSON without changing the Flutter application. For example:

```sql
UPDATE plants
SET subscription_payload = JSON_OBJECT(
  'event', 'subscribe',
  'plant', '{{site_id}}'
);
```

The Flutter normalizer supports common wrappers such as `data`, `payload`, `result`, and common field names for plant power, energy, irradiance, voltage, frequency, inverters, VCBs and breakers. Use the **Raw JSON** button in the Overview tab to see the actual message. Then add any vendor-specific aliases in:

```text
frontend/lib/services/scada_service.dart
```

A representative test payload is included at:

```text
database/scada_sample_payload.json
```

## 1. MySQL setup

`database/schema.sql` is the complete one-file database install. It creates
the `nuclei_tech_ticket` database, selects it, creates all tables, and inserts the
starter companies, plants, SCADA IDs and login accounts.

```bash
mysql -u root -p < database/schema.sql
```

## 2. Backend setup

```bash
cd backend
cp config.example.php config.php
composer install
```

Edit `config.php` with the database credentials, public backend URL and SMTP settings.

For an existing live database, run the ticket-numbering upgrade once in phpMyAdmin or MySQL:

```bash
mysql -u root -p nuclei_tech_ticket < database/migrate_ticket_numbering_v3.sql
```

If the database was created from an earlier package, you can also correct only the Vijayanth SCADA IDs with:

```bash
mysql -u root -p nuclei_tech_ticket < database/update_scada_ids_v2.sql
```

Start a development server:

```bash
php -S 0.0.0.0:8080
```

Health check:

```text
http://localhost:8080/api.php?action=health
```

Make sure `backend/uploads` is writable by the PHP process.

## 3. Gmail email setup

The backend uses PHPMailer and authenticated SMTP. For Gmail:

1. Enable two-step verification on `nfo.nucleitech@gmail.com`.
2. Create a Gmail App Password.
3. Put that App Password in `backend/config.php`.
4. Change `smtp.enabled` to `true`.

```php
'smtp' => [
    'enabled' => true,
    'host' => 'smtp.gmail.com',
    'port' => 587,
    'encryption' => 'tls',
    'username' => 'nfo.nucleitech@gmail.com',
    'password' => 'YOUR_16_CHARACTER_APP_PASSWORD',
],
```

Verify SMTP after configuration:

```bash
cd backend
php test_email.php
```

Emails are generated for:

- Ticket received by NUCLEI TECH
- New ticket received by the owner
- Support comment/reply
- Every ticket status update
- Resolved and closed tickets

## 4. Flutter frontend setup

Install Flutter, then run the included setup helper:

```bash
cd frontend
./setup_frontend.sh
```

Windows PowerShell / Command Prompt:

```bat
cd frontend
setup_frontend.bat
```

The helper generates Android, iOS, Web and Windows platform folders and runs `flutter pub get`. You may also run the equivalent commands manually:

```bash
flutter create --platforms=android,ios,web,windows .
flutter pub get
```

Set the backend URL in:

```text
frontend/lib/config.dart
```

Examples:

```dart
// Web and Windows
static const apiBaseUrl = 'http://localhost:8080/api.php';

// Android emulator
static const apiBaseUrl = 'http://10.0.2.2:8080/api.php';

// Physical phone on the same LAN
static const apiBaseUrl = 'http://192.168.1.10:8080/api.php';
```

Run:

```bash
flutter run
```

Build:

```bash
flutter build apk
flutter build appbundle
flutter build web
flutter build windows
flutter build ios
```

## Production checklist

- Use HTTPS for the API and image URLs.
- Restrict CORS to the deployed frontend domains.
- Change every starter password.
- Configure Gmail App Password or another transactional SMTP provider.
- Verify the WebSocket subscription command with the SCADA server owner.
- Verify a real payload and add exact vendor field aliases.
- Add Firebase Cloud Messaging if notifications must arrive while the app is fully closed.
- Store uploads in private object storage and add malware scanning.
- Add token expiry/refresh, rate limiting, backups and monitoring.

## Optional local SCADA test server

A mock server is included to test Overview, Inverters and VCB without production access:

```bash
cd tools
npm install
node mock_scada_server.js
```

Temporarily change plant WebSocket URLs:

```sql
UPDATE plants SET websocket_url = 'ws://localhost:5001';
```

For an Android emulator, use the host-reachable address supported by your environment. Restore the production URL afterward:

```sql
UPDATE plants
SET websocket_url = 'wss://vinobasolar.scadahub.in:5001';
```
