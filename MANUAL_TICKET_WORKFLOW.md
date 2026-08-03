# NUCLEI TECH — Manual Plant Ticket Workflow

This application intentionally uses a **manual ticket resolution workflow**.

## What is not used for ticket handling

- No ticket is sent through the SCADA WebSocket.
- No WebSocket event automatically marks a ticket resolved.
- No background process checks plant/inverter data to decide whether a ticket is solved.
- SCADA telemetry, where enabled elsewhere in the application, is display/monitoring data only and is not the authority for ticket resolution.

## Ticket creation

1. The authenticated user opens the required plant.
2. The user selects **Raise Ticket**.
3. The selected plant is bound to the ticket on the server.
4. The user provides category, title, description, priority and optional images.
5. The Flutter app submits the ticket through the authenticated HTTPS REST API.
6. MySQL remains the source of truth for the ticket.
7. The backend sends the new-ticket email to `info@orikscare.com`.
8. The user sees the new ticket in the application.

The support email should contain the same plant context shown in the application, including at minimum:

- ticket number
- company name
- plant ID / plant code where available
- plant name
- plant capacity where available
- category
- priority
- issue title
- issue description
- raised-by name
- raised-by email
- created date/time
- uploaded issue images or links

## Example

A user is inside **Plant A** and reports:

> Inverter 1 data is not coming.

The application creates a ticket tied to Plant A and emails the details to `info@orikscare.com`.

NUCLEI TECH support investigates the issue outside the automatic ticket engine. The application does **not** watch Inverter 1 and does **not** auto-resolve the ticket when data returns.

## Manual resolution

When support confirms the issue has been fixed:

1. A support user opens the ticket in the app.
2. Support selects **Resolved** (or another appropriate status).
3. Support enters a clear manual resolution note.
4. The backend updates the ticket transactionally.
5. The update is written to ticket history.
6. An in-app notification is created for the customer.
7. The backend sends a customer email from the configured NUCLEI TECH mailbox.

The resolution email should retain the same ticket/plant context as the original email and add:

- previous status
- new status
- manual resolution notes
- resolved-by support user
- resolved date/time

Recommended subject:

```text
[RESOLVED] <ticket-number> — <plant-name> — <issue-title>
```

## Production email configuration

`backend/config.php` should use the real SMTP provider for `info@orikscare.com`.

```php
'owner_email' => 'info@orikscare.com',
'mail_from_name' => 'NUCLEI TECH Support',
'mail_from_address' => 'info@orikscare.com',
'smtp' => [
    'enabled' => true,
    'host' => 'REAL_SMTP_HOST',
    'port' => 587,
    'encryption' => 'tls',
    'username' => 'info@orikscare.com',
    'password' => getenv('NUCLEI_SMTP_PASSWORD') ?: '',
],
```

Do not commit the live SMTP password.

## Production behavior

Use HTTPS for the Flutter API endpoint, restrict CORS to the deployed application domain, rotate seeded passwords, use secure server-side secrets, validate image uploads, rate-limit login/ticket endpoints, and back up the ticket database.
