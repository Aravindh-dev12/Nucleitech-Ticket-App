<?php
declare(strict_types=1);

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

function respond(array $payload, int $status = 200): void
{
    http_response_code($status);
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

$action = $_GET['action'] ?? '';
if ($action === 'health') {
    respond(['success' => true, 'message' => 'NUCLEI TECH API is running.']);
}

$configFile = __DIR__ . '/config.php';
if (!file_exists($configFile)) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Copy config.example.php to config.php and configure it.']);
    exit;
}

$config = require $configFile;
require_once __DIR__ . '/Mailer.php';

$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowedOrigins = $config['allowed_origins'] ?? ['*'];
if (in_array('*', $allowedOrigins, true)) {
    header('Access-Control-Allow-Origin: *');
} elseif ($origin !== '' && in_array($origin, $allowedOrigins, true)) {
    header("Access-Control-Allow-Origin: {$origin}");
    header('Vary: Origin');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

function getDb(array $config): mysqli
{
    static $db = null;
    if ($db instanceof mysqli) {
        return $db;
    }

    try {
        $db = new mysqli(
            $config['db_host'],
            $config['db_user'],
            $config['db_password'],
            $config['db_name'],
            (int) $config['db_port']
        );
    } catch (Throwable $error) {
        error_log('Database connection failed: ' . $error->getMessage());
        respond(['success' => false, 'message' => 'Database connection failed. Check backend/config.php.'], 500);
    }

    if ($db->connect_errno) {
        error_log('Database connection failed: ' . $db->connect_error);
        respond(['success' => false, 'message' => 'Database connection failed. Check backend/config.php.'], 500);
    }

    $db->set_charset('utf8mb4');
    return $db;
}

function requestBody(): array
{
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    if (strpos($contentType, 'application/json') !== false) {
        $decoded = json_decode(file_get_contents('php://input'), true);
        return is_array($decoded) ? $decoded : [];
    }
    return $_POST;
}

function bearerToken(): string
{
    $header = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    if ($header === '' && function_exists('getallheaders')) {
        $headers = getallheaders();
        $header = $headers['Authorization'] ?? $headers['authorization'] ?? '';
    }

    return preg_match('/Bearer\s+(\S+)/i', $header, $matches)
        ? $matches[1]
        : '';
}

function authenticatedUser(mysqli $db): array
{
    $token = bearerToken();
    if ($token === '') {
        respond(['success' => false, 'message' => 'Authentication required.'], 401);
    }

    $stmt = $db->prepare(
        "SELECT u.id,u.company_id,u.plant_id,u.name,u.email,u.phone,u.role,
                c.company_name,p.plant_name
         FROM users u
         LEFT JOIN companies c ON c.id=u.company_id
         LEFT JOIN plants p ON p.id=u.plant_id
         WHERE u.auth_token=? AND u.is_active=1
         LIMIT 1"
    );
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if (!$user) {
        respond(['success' => false, 'message' => 'Invalid or expired login.'], 401);
    }

    foreach (['id', 'company_id', 'plant_id'] as $field) {
        $user[$field] = $user[$field] === null ? null : (int) $user[$field];
    }

    return $user;
}

function isSupport(array $user): bool
{
    return in_array($user['role'], ['support_engineer', 'nuclei_admin'], true);
}

function canRaiseTicket(array $user): bool
{
    return in_array($user['role'], ['company_admin', 'plant_user'], true);
}

function canAccessPlant(mysqli $db, array $user, int $plantId): bool
{
    if (isSupport($user)) {
        return true;
    }

    if ($user['role'] === 'plant_user') {
        return $user['plant_id'] === $plantId;
    }

    if ($user['role'] === 'company_admin') {
        $stmt = $db->prepare(
            "SELECT 1 FROM plants
             WHERE id=? AND company_id=? AND is_active=1
             LIMIT 1"
        );
        $stmt->bind_param('ii', $plantId, $user['company_id']);
        $stmt->execute();
        return (bool) $stmt->get_result()->fetch_row();
    }

    return false;
}

function fetchPlant(mysqli $db, int $plantId): ?array
{
    $stmt = $db->prepare(
        "SELECT p.*,c.company_name,c.company_code
         FROM plants p
         JOIN companies c ON c.id=p.company_id
         WHERE p.id=? AND p.is_active=1
         LIMIT 1"
    );
    $stmt->bind_param('i', $plantId);
    $stmt->execute();
    $plant = $stmt->get_result()->fetch_assoc();

    if (!$plant) {
        return null;
    }

    $plant['id'] = (int) $plant['id'];
    $plant['company_id'] = (int) $plant['company_id'];
    $plant['capacity_mw'] = $plant['capacity_mw'] === null ? null : (float) $plant['capacity_mw'];
    $plant['scada_enabled'] = (bool) $plant['scada_enabled'];
    return $plant;
}

function fetchTicket(mysqli $db, int $ticketId): ?array
{
    $stmt = $db->prepare(
        "SELECT t.*,c.company_name,c.company_code,p.plant_name,p.plant_code,p.ticket_prefix,
                p.capacity_mw,p.scada_site_id,
                r.name AS raised_by_name,r.email AS raised_by_email,
                a.name AS assigned_to_name
         FROM tickets t
         JOIN companies c ON c.id=t.company_id
         JOIN plants p ON p.id=t.plant_id
         JOIN users r ON r.id=t.raised_by
         LEFT JOIN users a ON a.id=t.assigned_to
         WHERE t.id=? LIMIT 1"
    );
    $stmt->bind_param('i', $ticketId);
    $stmt->execute();
    $ticket = $stmt->get_result()->fetch_assoc();

    if (!$ticket) {
        return null;
    }

    foreach (['id', 'company_id', 'plant_id', 'raised_by', 'assigned_to'] as $field) {
        $ticket[$field] = $ticket[$field] === null ? null : (int) $ticket[$field];
    }
    $ticket['capacity_mw'] = $ticket['capacity_mw'] === null ? null : (float) $ticket['capacity_mw'];
    return $ticket;
}

function canAccessTicket(array $user, array $ticket): bool
{
    if (isSupport($user)) {
        return true;
    }

    if ($user['role'] === 'company_admin') {
        return $user['company_id'] === $ticket['company_id'];
    }

    if ($user['role'] === 'plant_user') {
        return $user['plant_id'] === $ticket['plant_id'];
    }

    return false;
}

function addHistory(
    mysqli $db,
    int $ticketId,
    int $userId,
    string $action,
    ?string $oldValue = null,
    ?string $newValue = null,
    ?string $notes = null
): void {
    $stmt = $db->prepare(
        "INSERT INTO ticket_history
            (ticket_id,changed_by,action,old_value,new_value,notes)
         VALUES (?,?,?,?,?,?)"
    );
    $stmt->bind_param('iissss', $ticketId, $userId, $action, $oldValue, $newValue, $notes);
    $stmt->execute();
}

function notifyUser(
    mysqli $db,
    int $userId,
    ?int $ticketId,
    string $title,
    string $message,
    string $type
): void {
    $stmt = $db->prepare(
        "INSERT INTO notifications
            (user_id,ticket_id,title,message,notification_type)
         VALUES (?,?,?,?,?)"
    );
    $stmt->bind_param('iisss', $userId, $ticketId, $title, $message, $type);
    $stmt->execute();
}

function notifySupport(
    mysqli $db,
    int $ticketId,
    string $title,
    string $message,
    string $type
): void {
    $result = $db->query(
        "SELECT id FROM users
         WHERE role IN ('support_engineer','nuclei_admin') AND is_active=1"
    );

    while ($row = $result->fetch_assoc()) {
        notifyUser($db, (int) $row['id'], $ticketId, $title, $message, $type);
    }
}

function cleanTicketPrefix(string $value): string
{
    $clean = strtoupper((string) preg_replace('/[^A-Za-z0-9]/', '', $value));
    return substr($clean, 0, 12);
}

function ticketPrefixFromPlant(array $plant): string
{
    $configured = cleanTicketPrefix((string) ($plant['ticket_prefix'] ?? ''));
    if ($configured !== '') {
        return $configured;
    }

    $plantCodeParts = explode('-', (string) ($plant['plant_code'] ?? ''));
    if (count($plantCodeParts) >= 2) {
        $fromCode = cleanTicketPrefix($plantCodeParts[1]);
        if ($fromCode !== '') {
            return $fromCode;
        }
    }

    $words = preg_split('/\s+/', (string) ($plant['plant_name'] ?? ''), -1, PREG_SPLIT_NO_EMPTY);
    $initials = '';
    foreach ($words ?: [] as $word) {
        $initials .= substr(cleanTicketPrefix($word), 0, 1);
    }

    return $initials !== '' ? substr($initials, 0, 6) : 'PLANT';
}

function nextTicketSequence(mysqli $db, int $plantId): int
{
    $stmt = $db->prepare(
        "INSERT IGNORE INTO ticket_counters (plant_id,next_sequence)
         VALUES (?,1)"
    );
    $stmt->bind_param('i', $plantId);
    $stmt->execute();

    $stmt = $db->prepare(
        "SELECT next_sequence FROM ticket_counters
         WHERE plant_id=?
         FOR UPDATE"
    );
    $stmt->bind_param('i', $plantId);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();

    $sequence = max(1, (int) ($row['next_sequence'] ?? 1));

    $stmt = $db->prepare(
        "UPDATE ticket_counters
         SET next_sequence=?
         WHERE plant_id=?"
    );
    $nextSequence = $sequence + 1;
    $stmt->bind_param('ii', $nextSequence, $plantId);
    $stmt->execute();

    return $sequence;
}

function buildTicketNumber(array $plant, int $sequence): string
{
    return sprintf(
        'NT-%s-%s',
        ticketPrefixFromPlant($plant),
        str_pad((string) $sequence, 2, '0', STR_PAD_LEFT)
    );
}

function friendlyLabel(string $value): string
{
    return ucwords(str_replace('_', ' ', $value));
}

function capacityLabel(array $plant): string
{
    return $plant['capacity_mw'] === null
        ? 'Not set'
        : number_format((float) $plant['capacity_mw'], 2) . ' MW';
}

function ticketAgeLabel(?string $start, ?string $end = null): string
{
    if ($start === null || $start === '') {
        return 'Not available';
    }

    try {
        $startedAt = new DateTimeImmutable($start);
        $endedAt = $end ? new DateTimeImmutable($end) : new DateTimeImmutable();
        $diff = $startedAt->diff($endedAt);
    } catch (Throwable $error) {
        return 'Not available';
    }

    $parts = [];
    if ($diff->days > 0) {
        $parts[] = $diff->days . ' day' . ($diff->days === 1 ? '' : 's');
    }
    if ($diff->h > 0) {
        $parts[] = $diff->h . ' hour' . ($diff->h === 1 ? '' : 's');
    }
    if (!$parts && $diff->i > 0) {
        $parts[] = $diff->i . ' minute' . ($diff->i === 1 ? '' : 's');
    }

    return $parts ? implode(' ', $parts) : 'Less than a minute';
}

function emailReportTable(array $rows): string
{
    $html = '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:18px 0;border:1px solid #d8e6fa">';
    foreach ($rows as $label => $value) {
        $display = trim((string) $value);
        if ($display === '') {
            $display = 'Not set';
        }

        $html .= '<tr>'
            . '<td style="width:34%;padding:10px 12px;border-bottom:1px solid #e8f0fb;background:#f7fbff;color:#5b6b82;font-size:13px"><strong>'
            . htmlspecialchars((string) $label)
            . '</strong></td>'
            . '<td style="padding:10px 12px;border-bottom:1px solid #e8f0fb;color:#172033;font-size:14px">'
            . htmlspecialchars($display)
            . '</td>'
            . '</tr>';
    }

    return $html . '</table>';
}

function emailNoteBox(string $title, string $text): string
{
    if (trim($text) === '') {
        return '';
    }

    return '<p style="margin:18px 0 8px"><strong>' . htmlspecialchars($title) . '</strong></p>'
        . '<div style="padding:14px;background:#f7fbff;border:1px solid #d8e6fa;border-radius:10px;white-space:normal">'
        . nl2br(htmlspecialchars($text))
        . '</div>';
}

function uploadTicketImages(
    mysqli $db,
    array $config,
    int $ticketId,
    int $userId
): array {
    if (!isset($_FILES['images'])) {
        return [];
    }

    $names = $_FILES['images']['name'];
    $tmpNames = $_FILES['images']['tmp_name'];
    $errors = $_FILES['images']['error'];
    $sizes = $_FILES['images']['size'];

    if (!is_array($names)) {
        $names = [$names];
        $tmpNames = [$tmpNames];
        $errors = [$errors];
        $sizes = [$sizes];
    }

    if (count($names) > (int) $config['max_images_per_ticket']) {
        respond(['success' => false, 'message' => 'Too many images attached.'], 422);
    }

    $directory = (string) $config['upload_directory'];
    if (!is_dir($directory) && !mkdir($directory, 0775, true)) {
        respond(['success' => false, 'message' => 'Upload directory is unavailable.'], 500);
    }

    $allowed = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/heic' => 'heic',
    ];

    $finfo = new finfo(FILEINFO_MIME_TYPE);
    $saved = [];

    foreach ($names as $index => $originalName) {
        if ((int) $errors[$index] === UPLOAD_ERR_NO_FILE) {
            continue;
        }
        if ((int) $errors[$index] !== UPLOAD_ERR_OK) {
            respond(['success' => false, 'message' => "Image upload failed: {$originalName}"], 422);
        }
        if ((int) $sizes[$index] > (int) $config['max_image_bytes']) {
            respond(['success' => false, 'message' => "Image is too large: {$originalName}"], 422);
        }

        $mime = $finfo->file($tmpNames[$index]);
        if (!isset($allowed[$mime])) {
            respond(['success' => false, 'message' => "Unsupported image format: {$originalName}"], 422);
        }

        $storedName = bin2hex(random_bytes(18)) . '.' . $allowed[$mime];
        $destination = $directory . DIRECTORY_SEPARATOR . $storedName;
        if (!move_uploaded_file($tmpNames[$index], $destination)) {
            respond(['success' => false, 'message' => 'Unable to save an attached image.'], 500);
        }

        $url = rtrim((string) $config['app_url'], '/') . '/uploads/' . $storedName;
        $size = (int) $sizes[$index];

        $stmt = $db->prepare(
            "INSERT INTO ticket_attachments
                (ticket_id,uploaded_by,original_name,stored_name,file_url,mime_type,file_size)
             VALUES (?,?,?,?,?,?,?)"
        );
        $stmt->bind_param(
            'iissssi',
            $ticketId,
            $userId,
            $originalName,
            $storedName,
            $url,
            $mime,
            $size
        );
        $stmt->execute();

        $saved[] = [
            'id' => (int) $stmt->insert_id,
            'file_url' => $url,
            'mime_type' => $mime,
        ];
    }

    return $saved;
}

try {
    $db = getDb($config);

    switch ($action) {
        case 'db_health':
            respond([
                'success' => true,
                'message' => 'NUCLEI TECH API and database are connected.',
                'database' => $config['db_name'],
            ]);

        case 'login':
            $input = requestBody();
            $email = strtolower(trim((string) ($input['email'] ?? '')));
            $password = (string) ($input['password'] ?? '');

            if ($email === '' || $password === '') {
                respond(['success' => false, 'message' => 'Email and password are required.'], 422);
            }

            $stmt = $db->prepare(
                "SELECT id,password_hash FROM users
                 WHERE email=? AND is_active=1 LIMIT 1"
            );
            $stmt->bind_param('s', $email);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();

            if (!$row || !password_verify($password, $row['password_hash'])) {
                respond(['success' => false, 'message' => 'Incorrect email or password.'], 401);
            }

            $token = bin2hex(random_bytes(32));
            $userId = (int) $row['id'];
            $stmt = $db->prepare(
                "UPDATE users SET auth_token=?,token_created_at=NOW() WHERE id=?"
            );
            $stmt->bind_param('si', $token, $userId);
            $stmt->execute();

            $_SERVER['HTTP_AUTHORIZATION'] = "Bearer {$token}";
            respond([
                'success' => true,
                'token' => $token,
                'user' => authenticatedUser($db),
            ]);

        case 'logout':
            $user = authenticatedUser($db);
            $stmt = $db->prepare("UPDATE users SET auth_token=NULL WHERE id=?");
            $stmt->bind_param('i', $user['id']);
            $stmt->execute();
            respond(['success' => true, 'message' => 'Signed out.']);

        case 'me':
            respond(['success' => true, 'user' => authenticatedUser($db)]);

        case 'plants':
            $user = authenticatedUser($db);
            $baseSql =
                "SELECT p.id,p.company_id,p.plant_code,p.ticket_prefix,p.plant_name,p.capacity_mw,
                        p.scada_site_id,p.websocket_url,p.scada_enabled,
                        c.company_name,c.company_code,
                        COUNT(t.id) AS total_tickets,
                        SUM(t.status IN ('open','assigned','in_progress','waiting_for_user','on_hold','reopened')) AS active_tickets,
                        SUM(t.status IN ('resolved','closed')) AS solved_tickets
                 FROM plants p
                 JOIN companies c ON c.id=p.company_id
                 LEFT JOIN tickets t ON t.plant_id=p.id
                 WHERE p.is_active=1";

            if ($user['role'] === 'plant_user') {
                $stmt = $db->prepare($baseSql . " AND p.id=? GROUP BY p.id ORDER BY p.plant_name");
                $stmt->bind_param('i', $user['plant_id']);
            } elseif ($user['role'] === 'company_admin') {
                $stmt = $db->prepare($baseSql . " AND p.company_id=? GROUP BY p.id ORDER BY p.plant_name");
                $stmt->bind_param('i', $user['company_id']);
            } else {
                $stmt = $db->prepare($baseSql . " GROUP BY p.id ORDER BY c.company_name,p.plant_name");
            }

            $stmt->execute();
            $plants = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
            foreach ($plants as &$plant) {
                foreach (['id', 'company_id', 'total_tickets', 'active_tickets', 'solved_tickets'] as $field) {
                    $plant[$field] = (int) $plant[$field];
                }
                $plant['capacity_mw'] = $plant['capacity_mw'] === null ? null : (float) $plant['capacity_mw'];
                $plant['scada_enabled'] = (bool) $plant['scada_enabled'];
            }

            respond(['success' => true, 'plants' => $plants]);

        case 'scada_config':
            $user = authenticatedUser($db);
            $plantId = (int) ($_GET['plant_id'] ?? 0);
            if ($plantId <= 0 || !canAccessPlant($db, $user, $plantId)) {
                respond(['success' => false, 'message' => 'Plant access denied.'], 403);
            }

            $plant = fetchPlant($db, $plantId);
            if (!$plant) {
                respond(['success' => false, 'message' => 'Plant not found.'], 404);
            }

            $subscription = json_decode((string) ($plant['subscription_payload'] ?? ''), true);
            if (!is_array($subscription)) {
                $subscription = ['action' => 'subscribe', 'siteId' => '{{site_id}}'];
            }

            respond([
                'success' => true,
                'config' => [
                    'plant_id' => $plant['id'],
                    'site_id' => $plant['scada_site_id'],
                    'websocket_url' => $plant['websocket_url'],
                    'subscription_payload' => $subscription,
                    'enabled' => $plant['scada_enabled'],
                ],
            ]);

        case 'scada_snapshot':
            $user = authenticatedUser($db);
            $plantId = (int) ($_GET['plant_id'] ?? 0);
            if ($plantId <= 0 || !canAccessPlant($db, $user, $plantId)) {
                respond(['success' => false, 'message' => 'Plant access denied.'], 403);
            }

            $stmt = $db->prepare(
                "SELECT payload_json,received_at
                 FROM scada_snapshots
                 WHERE plant_id=?
                 ORDER BY received_at DESC,id DESC
                 LIMIT 1"
            );
            $stmt->bind_param('i', $plantId);
            $stmt->execute();
            $row = $stmt->get_result()->fetch_assoc();

            respond([
                'success' => true,
                'snapshot' => $row ? [
                    'payload' => json_decode($row['payload_json'], true),
                    'received_at' => $row['received_at'],
                ] : null,
            ]);

        case 'save_scada_snapshot':
            $user = authenticatedUser($db);
            $input = requestBody();
            $plantId = (int) ($input['plant_id'] ?? 0);
            $payload = $input['payload'] ?? null;

            if ($plantId <= 0 || !canAccessPlant($db, $user, $plantId)) {
                respond(['success' => false, 'message' => 'Plant access denied.'], 403);
            }
            if (!is_array($payload)) {
                respond(['success' => false, 'message' => 'SCADA payload must be a JSON object.'], 422);
            }

            $encoded = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
            $stmt = $db->prepare(
                "INSERT INTO scada_snapshots (plant_id,payload_json,received_at)
                 VALUES (?, ?, NOW())"
            );
            $stmt->bind_param('is', $plantId, $encoded);
            $stmt->execute();

            // Keep only recent snapshots per plant.
            $stmt = $db->prepare(
                "DELETE FROM scada_snapshots
                 WHERE plant_id=? AND id NOT IN (
                    SELECT id FROM (
                        SELECT id FROM scada_snapshots
                        WHERE plant_id=? ORDER BY id DESC LIMIT 100
                    ) latest
                 )"
            );
            $stmt->bind_param('ii', $plantId, $plantId);
            $stmt->execute();

            respond(['success' => true]);

        case 'tickets':
            $user = authenticatedUser($db);
            $plantId = isset($_GET['plant_id']) ? (int) $_GET['plant_id'] : 0;
            $status = trim((string) ($_GET['status'] ?? ''));

            $where = [];
            $types = '';
            $params = [];

            if ($user['role'] === 'plant_user') {
                $where[] = 't.plant_id=?';
                $types .= 'i';
                $params[] = $user['plant_id'];
            } elseif ($user['role'] === 'company_admin') {
                $where[] = 't.company_id=?';
                $types .= 'i';
                $params[] = $user['company_id'];
            }

            if ($plantId > 0) {
                if (!canAccessPlant($db, $user, $plantId)) {
                    respond(['success' => false, 'message' => 'Plant access denied.'], 403);
                }
                $where[] = 't.plant_id=?';
                $types .= 'i';
                $params[] = $plantId;
            }

            if ($status !== '') {
                $where[] = 't.status=?';
                $types .= 's';
                $params[] = $status;
            }

            $sql =
                "SELECT t.id,t.ticket_number,t.ticket_sequence,t.subject,t.category,t.priority,t.status,
                        t.created_at,t.updated_at,p.plant_name,p.capacity_mw,p.scada_site_id,
                        c.company_name,r.name AS raised_by_name,a.name AS assigned_to_name,
                        (SELECT COUNT(*) FROM ticket_attachments x WHERE x.ticket_id=t.id) AS attachment_count
                 FROM tickets t
                 JOIN plants p ON p.id=t.plant_id
                 JOIN companies c ON c.id=t.company_id
                 JOIN users r ON r.id=t.raised_by
                 LEFT JOIN users a ON a.id=t.assigned_to";

            if ($where) {
                $sql .= ' WHERE ' . implode(' AND ', $where);
            }
            $sql .= ' ORDER BY t.created_at DESC LIMIT 500';

            $stmt = $db->prepare($sql);
            if ($params) {
                $stmt->bind_param($types, ...$params);
            }
            $stmt->execute();
            $tickets = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

            foreach ($tickets as &$ticket) {
                $ticket['id'] = (int) $ticket['id'];
                $ticket['ticket_sequence'] = (int) $ticket['ticket_sequence'];
                $ticket['attachment_count'] = (int) $ticket['attachment_count'];
                $ticket['capacity_mw'] = $ticket['capacity_mw'] === null ? null : (float) $ticket['capacity_mw'];
            }

            respond(['success' => true, 'tickets' => $tickets]);

        case 'create_ticket':
            $user = authenticatedUser($db);
            if (!canRaiseTicket($user)) {
                respond(['success' => false, 'message' => 'Your account cannot raise tickets.'], 403);
            }

            $input = requestBody();
            $plantId = (int) ($input['plant_id'] ?? 0);
            $category = trim((string) ($input['category'] ?? 'General'));
            $subject = trim((string) ($input['subject'] ?? ''));
            $description = trim((string) ($input['description'] ?? ''));
            $priority = strtolower(trim((string) ($input['priority'] ?? 'medium')));

            if ($plantId <= 0 || strlen($subject) < 5 || strlen($description) < 10) {
                respond(['success' => false, 'message' => 'Plant, clear title, and detailed description are required.'], 422);
            }
            if (!canAccessPlant($db, $user, $plantId)) {
                respond(['success' => false, 'message' => 'Plant access denied.'], 403);
            }
            if (!in_array($priority, ['low', 'medium', 'high', 'critical'], true)) {
                respond(['success' => false, 'message' => 'Invalid priority.'], 422);
            }

            $plant = fetchPlant($db, $plantId);
            if (!$plant) {
                respond(['success' => false, 'message' => 'Plant not found.'], 404);
            }

            $companyId = (int) $plant['company_id'];
            $raisedBy = (int) $user['id'];

            $ownerResult = $db->query(
                "SELECT id FROM users
                 WHERE role='nuclei_admin' AND is_active=1
                 ORDER BY id LIMIT 1"
            );
            $ownerRow = $ownerResult ? $ownerResult->fetch_assoc() : null;
            $ownerId = $ownerRow ? (int) $ownerRow['id'] : null;

            $db->begin_transaction();
            try {
                $ticketSequence = nextTicketSequence($db, $plantId);
                $ticketNumber = buildTicketNumber($plant, $ticketSequence);

                $stmt = $db->prepare(
                    "INSERT INTO tickets
                        (ticket_number,ticket_sequence,company_id,plant_id,raised_by,assigned_to,
                         category,subject,description,priority,status)
                     VALUES (?,?,?,?,?,?,?,?,?,?,'open')"
                );
                $stmt->bind_param(
                    'siiiiissss',
                    $ticketNumber,
                    $ticketSequence,
                    $companyId,
                    $plantId,
                    $raisedBy,
                    $ownerId,
                    $category,
                    $subject,
                    $description,
                    $priority
                );
                $stmt->execute();
                $ticketId = (int) $stmt->insert_id;

                addHistory($db, $ticketId, $raisedBy, 'ticket_created', null, 'open', 'Ticket raised by customer.');
                if ($ownerId !== null) {
                    addHistory(
                        $db,
                        $ticketId,
                        $raisedBy,
                        'assigned_to_owner',
                        null,
                        (string) $ownerId,
                        'Automatically routed to the NUCLEI TECH owner.'
                    );
                }
                $attachments = uploadTicketImages($db, $config, $ticketId, $raisedBy);

                notifyUser(
                    $db,
                    $raisedBy,
                    $ticketId,
                    'Ticket received',
                    "{$ticketNumber} was received by NUCLEI TECH.",
                    'ticket_created'
                );
                notifySupport(
                    $db,
                    $ticketId,
                    'New ticket received',
                    "{$ticketNumber}: {$subject} at {$plant['plant_name']}.",
                    'ticket_created'
                );

                $db->commit();
            } catch (Throwable $error) {
                $db->rollback();
                throw $error;
            }

            $attachmentCount = count($attachments);
            $ticketReport = emailReportTable([
                'Ticket Number' => $ticketNumber,
                'Plant Short ID' => ticketPrefixFromPlant($plant),
                'Company' => $plant['company_name'],
                'Plant' => $plant['plant_name'],
                'Capacity' => capacityLabel($plant),
                'SCADA ID' => $plant['scada_site_id'],
                'Category' => $category,
                'Priority' => friendlyLabel($priority),
                'Status' => 'Open',
                'Raised By' => $user['name'] . ' <' . $user['email'] . '>',
                'Images Attached' => (string) $attachmentCount,
                'Created At' => date('Y-m-d H:i:s'),
            ]);

            $customerBody = emailLayout(
                'Ticket received',
                '<p>Hello <strong>' . htmlspecialchars($user['name']) . '</strong>,</p>'
                . '<p>Your plant issue has been received and assigned to NUCLEI TECH support.</p>'
                . $ticketReport
                . emailNoteBox('Issue Summary', $subject)
                . emailNoteBox('Issue Description', $description)
                . '<p>The ticket status will update automatically in the NUCLEI TECH app as support works on it.</p>'
            );
            sendAppEmail($config, $user['email'], "Ticket received - {$ticketNumber}", $customerBody);

            $ownerBody = emailLayout(
                'New plant ticket report',
                '<p>A new production ticket has been registered and routed to the owner queue.</p>'
                . $ticketReport
                . emailNoteBox('Issue Summary', $subject)
                . emailNoteBox('Issue Description', $description)
            );
            sendAppEmail($config, (string) $config['owner_email'], "New ticket - {$ticketNumber}", $ownerBody);

            respond([
                'success' => true,
                'message' => 'Ticket sent successfully.',
                'ticket' => [
                    'id' => $ticketId,
                    'ticket_number' => $ticketNumber,
                    'ticket_sequence' => $ticketSequence,
                    'status' => 'open',
                    'priority' => $priority,
                    'attachments' => $attachments,
                ],
            ], 201);

        case 'ticket':
            $user = authenticatedUser($db);
            $ticketId = (int) ($_GET['id'] ?? 0);
            $ticket = fetchTicket($db, $ticketId);

            if (!$ticket) {
                respond(['success' => false, 'message' => 'Ticket not found.'], 404);
            }
            if (!canAccessTicket($user, $ticket)) {
                respond(['success' => false, 'message' => 'Ticket access denied.'], 403);
            }

            $stmt = $db->prepare(
                "SELECT id,original_name,file_url,mime_type,file_size,created_at
                 FROM ticket_attachments WHERE ticket_id=? ORDER BY created_at"
            );
            $stmt->bind_param('i', $ticketId);
            $stmt->execute();
            $attachments = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

            $commentsSql =
                "SELECT tc.id,tc.comment,tc.is_internal,tc.created_at,
                        u.name AS user_name,u.role AS user_role
                 FROM ticket_comments tc
                 JOIN users u ON u.id=tc.user_id
                 WHERE tc.ticket_id=?";
            if (!isSupport($user)) {
                $commentsSql .= ' AND tc.is_internal=0';
            }
            $commentsSql .= ' ORDER BY tc.created_at';

            $stmt = $db->prepare($commentsSql);
            $stmt->bind_param('i', $ticketId);
            $stmt->execute();
            $comments = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

            $stmt = $db->prepare(
                "SELECT h.id,h.action,h.old_value,h.new_value,h.notes,h.created_at,
                        u.name AS changed_by_name
                 FROM ticket_history h
                 JOIN users u ON u.id=h.changed_by
                 WHERE h.ticket_id=? ORDER BY h.created_at"
            );
            $stmt->bind_param('i', $ticketId);
            $stmt->execute();
            $history = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

            respond([
                'success' => true,
                'ticket' => $ticket,
                'attachments' => $attachments,
                'comments' => $comments,
                'history' => $history,
            ]);

        case 'add_comment':
            $user = authenticatedUser($db);
            $input = requestBody();
            $ticketId = (int) ($input['ticket_id'] ?? 0);
            $comment = trim((string) ($input['comment'] ?? ''));
            $isInternal = !empty($input['is_internal']);

            if ($comment === '') {
                respond(['success' => false, 'message' => 'Comment is required.'], 422);
            }

            $ticket = fetchTicket($db, $ticketId);
            if (!$ticket) {
                respond(['success' => false, 'message' => 'Ticket not found.'], 404);
            }
            if (!canAccessTicket($user, $ticket)) {
                respond(['success' => false, 'message' => 'Ticket access denied.'], 403);
            }
            if ($isInternal && !isSupport($user)) {
                respond(['success' => false, 'message' => 'Internal comments are restricted to support.'], 403);
            }

            $internal = $isInternal ? 1 : 0;
            $stmt = $db->prepare(
                "INSERT INTO ticket_comments (ticket_id,user_id,comment,is_internal)
                 VALUES (?,?,?,?)"
            );
            $stmt->bind_param('iisi', $ticketId, $user['id'], $comment, $internal);
            $stmt->execute();

            addHistory(
                $db,
                $ticketId,
                $user['id'],
                'comment_added',
                null,
                null,
                $isInternal ? 'Internal support note.' : 'Public ticket message.'
            );

            if (!$isInternal) {
                if (isSupport($user)) {
                    notifyUser(
                        $db,
                        $ticket['raised_by'],
                        $ticketId,
                        'New support reply',
                        "NUCLEI TECH replied to {$ticket['ticket_number']}.",
                        'comment'
                    );
                    $body = emailLayout(
                        'New ticket reply',
                        '<p>NUCLEI TECH replied to ticket <strong>' . htmlspecialchars($ticket['ticket_number']) . '</strong>.</p>'
                        . '<p style="padding:14px;background:#f2f7f8;border-radius:10px">' . nl2br(htmlspecialchars($comment)) . '</p>'
                    );
                    sendAppEmail($config, $ticket['raised_by_email'], "Ticket reply - {$ticket['ticket_number']}", $body);
                } else {
                    notifySupport(
                        $db,
                        $ticketId,
                        'Customer replied',
                        "{$user['name']} replied to {$ticket['ticket_number']}.",
                        'comment'
                    );
                }
            }

            respond(['success' => true, 'message' => 'Comment added.'], 201);

        case 'update_status':
            $user = authenticatedUser($db);
            if (!isSupport($user)) {
                respond(['success' => false, 'message' => 'Support access is required.'], 403);
            }

            $input = requestBody();
            $ticketId = (int) ($input['ticket_id'] ?? 0);
            $status = strtolower(trim((string) ($input['status'] ?? '')));
            $resolutionNotes = trim((string) ($input['resolution_notes'] ?? ''));

            $allowed = [
                'open', 'assigned', 'in_progress', 'waiting_for_user', 'on_hold',
                'resolved', 'closed', 'reopened', 'cancelled',
            ];
            if (!in_array($status, $allowed, true)) {
                respond(['success' => false, 'message' => 'Invalid ticket status.'], 422);
            }

            $ticket = fetchTicket($db, $ticketId);
            if (!$ticket) {
                respond(['success' => false, 'message' => 'Ticket not found.'], 404);
            }

            $now = date('Y-m-d H:i:s');
            $resolvedAt = $ticket['resolved_at'];
            $closedAt = $ticket['closed_at'];
            if ($status === 'resolved' && $resolvedAt === null) {
                $resolvedAt = $now;
            }
            if ($status === 'closed') {
                $resolvedAt = $resolvedAt ?? $now;
                $closedAt = $now;
            }
            if ($status === 'reopened') {
                $closedAt = null;
            }
            $finalNotes = $resolutionNotes !== '' ? $resolutionNotes : $ticket['resolution_notes'];

            $stmt = $db->prepare(
                "UPDATE tickets
                 SET status=?,resolution_notes=?,resolved_at=?,closed_at=?
                 WHERE id=?"
            );
            $stmt->bind_param('ssssi', $status, $finalNotes, $resolvedAt, $closedAt, $ticketId);
            $stmt->execute();

            addHistory(
                $db,
                $ticketId,
                $user['id'],
                'status_changed',
                $ticket['status'],
                $status,
                $resolutionNotes !== '' ? $resolutionNotes : null
            );

            $friendlyStatus = friendlyLabel($status);
            notifyUser(
                $db,
                $ticket['raised_by'],
                $ticketId,
                "Ticket {$friendlyStatus}",
                "{$ticket['ticket_number']} is now {$friendlyStatus}.",
                'status_changed'
            );
            notifySupport(
                $db,
                $ticketId,
                "Ticket {$friendlyStatus}",
                "{$ticket['ticket_number']} was changed to {$friendlyStatus} by {$user['name']}.",
                'status_changed'
            );

            $ticketReport = emailReportTable([
                'Ticket Number' => $ticket['ticket_number'],
                'Company' => $ticket['company_name'],
                'Plant' => $ticket['plant_name'],
                'Plant Short ID' => ticketPrefixFromPlant($ticket),
                'SCADA ID' => $ticket['scada_site_id'],
                'Previous Status' => friendlyLabel($ticket['status']),
                'Current Status' => $friendlyStatus,
                'Updated By' => $user['name'],
                'Raised By' => $ticket['raised_by_name'] . ' <' . $ticket['raised_by_email'] . '>',
                'Created At' => $ticket['created_at'],
                'Updated At' => $now,
                'Age' => ticketAgeLabel($ticket['created_at'], $status === 'resolved' || $status === 'closed' ? $now : null),
            ]);

            $body = emailLayout(
                "Ticket {$friendlyStatus}",
                '<p>Hello <strong>' . htmlspecialchars($ticket['raised_by_name']) . '</strong>,</p>'
                . '<p>Your ticket is now <strong>' . htmlspecialchars($friendlyStatus) . '</strong>.</p>'
                . $ticketReport
                . emailNoteBox('NUCLEI TECH Update', $resolutionNotes)
                . '<p>Open the NUCLEI TECH app to view the complete history and reply.</p>'
            );
            sendAppEmail(
                $config,
                $ticket['raised_by_email'],
                "Ticket {$friendlyStatus} - {$ticket['ticket_number']}",
                $body
            );

            $ownerBody = emailLayout(
                "Ticket {$friendlyStatus} report",
                '<p>The ticket status was updated in the live database and is visible in the app.</p>'
                . $ticketReport
                . emailNoteBox('Resolution / Update Notes', $resolutionNotes)
            );
            sendAppEmail(
                $config,
                (string) $config['owner_email'],
                "Ticket {$friendlyStatus} report - {$ticket['ticket_number']}",
                $ownerBody
            );

            respond(['success' => true, 'message' => "Ticket changed to {$friendlyStatus}."]);

        case 'notifications':
            $user = authenticatedUser($db);
            $stmt = $db->prepare(
                "SELECT n.id,n.ticket_id,n.title,n.message,n.notification_type,
                        n.is_read,n.created_at,t.ticket_number
                 FROM notifications n
                 LEFT JOIN tickets t ON t.id=n.ticket_id
                 WHERE n.user_id=?
                 ORDER BY n.created_at DESC LIMIT 200"
            );
            $stmt->bind_param('i', $user['id']);
            $stmt->execute();
            $notifications = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

            foreach ($notifications as &$notification) {
                $notification['id'] = (int) $notification['id'];
                $notification['ticket_id'] = $notification['ticket_id'] === null
                    ? null
                    : (int) $notification['ticket_id'];
                $notification['is_read'] = (bool) $notification['is_read'];
            }

            respond(['success' => true, 'notifications' => $notifications]);

        case 'mark_notification_read':
            $user = authenticatedUser($db);
            $input = requestBody();
            $notificationId = (int) ($input['notification_id'] ?? 0);

            $stmt = $db->prepare(
                "UPDATE notifications SET is_read=1 WHERE id=? AND user_id=?"
            );
            $stmt->bind_param('ii', $notificationId, $user['id']);
            $stmt->execute();
            respond(['success' => true]);

        case 'register_device':
            $user = authenticatedUser($db);
            $input = requestBody();
            $platform = strtolower(trim((string) ($input['platform'] ?? '')));
            $deviceToken = trim((string) ($input['device_token'] ?? ''));

            if (!in_array($platform, ['android', 'ios', 'web', 'windows'], true) || $deviceToken === '') {
                respond(['success' => false, 'message' => 'Invalid device registration.'], 422);
            }

            $stmt = $db->prepare(
                "INSERT INTO device_tokens (user_id,platform,device_token)
                 VALUES (?,?,?)"
            );
            $stmt->bind_param('iss', $user['id'], $platform, $deviceToken);
            $stmt->execute();
            respond(['success' => true]);

        default:
            respond(['success' => false, 'message' => 'Unknown API action.'], 404);
    }
} catch (mysqli_sql_exception $error) {
    error_log($error->getMessage());
    respond(['success' => false, 'message' => 'A database operation failed.'], 500);
} catch (Throwable $error) {
    error_log($error->getMessage());
    respond(['success' => false, 'message' => 'An unexpected server error occurred.'], 500);
}
