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

$configFile = __DIR__ . '/config.php';
if (!file_exists($configFile)) {
    respond(['success' => false, 'message' => 'Backend configuration is missing.'], 500);
}
$config = require $configFile;

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

function db(array $config): mysqli
{
    try {
        $db = new mysqli(
            $config['db_host'],
            $config['db_user'],
            $config['db_password'],
            $config['db_name'],
            (int) $config['db_port']
        );
    } catch (Throwable $error) {
        error_log('Admin API database connection failed: ' . $error->getMessage());
        respond(['success' => false, 'message' => 'Database connection failed.'], 500);
    }

    if ($db->connect_errno) {
        error_log('Admin API database connection failed: ' . $db->connect_error);
        respond(['success' => false, 'message' => 'Database connection failed.'], 500);
    }

    $db->set_charset('utf8mb4');
    return $db;
}

function requestBody(): array
{
    $decoded = json_decode(file_get_contents('php://input'), true);
    return is_array($decoded) ? $decoded : [];
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

function requireNucleiAdmin(mysqli $db): array
{
    $token = bearerToken();
    if ($token === '') {
        respond(['success' => false, 'message' => 'Authentication required.'], 401);
    }

    $stmt = $db->prepare(
        "SELECT id,name,email,role FROM users
         WHERE auth_token=? AND is_active=1
         LIMIT 1"
    );
    $stmt->bind_param('s', $token);
    $stmt->execute();
    $user = $stmt->get_result()->fetch_assoc();

    if (!$user) {
        respond(['success' => false, 'message' => 'Invalid or expired login.'], 401);
    }
    if ($user['role'] !== 'nuclei_admin') {
        respond(['success' => false, 'message' => 'NUCLEI TECH admin access is required.'], 403);
    }

    $user['id'] = (int) $user['id'];
    return $user;
}

function fetchPlant(mysqli $db, int $plantId): ?array
{
    $stmt = $db->prepare(
        "SELECT p.id,p.company_id,p.plant_name,c.company_name
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
    return $plant;
}

function normalizePlantUser(array &$user): void
{
    $user['id'] = (int) $user['id'];
    $user['plant_id'] = (int) $user['plant_id'];
    $user['company_id'] = (int) $user['company_id'];
    $user['is_active'] = (bool) $user['is_active'];
}

function listPlantUsers(mysqli $db, ?int $plantId = null): array
{
    $sql =
        "SELECT u.id,u.company_id,u.plant_id,u.name,u.email,u.phone,u.is_active,u.created_at,u.updated_at,
                p.plant_name,c.company_name
         FROM users u
         JOIN plants p ON p.id=u.plant_id
         JOIN companies c ON c.id=u.company_id
         WHERE u.role='plant_user'";

    if ($plantId !== null) {
        $sql .= ' AND u.plant_id=?';
    }
    $sql .= ' ORDER BY c.company_name,p.plant_name,u.name,u.email';

    $stmt = $db->prepare($sql);
    if ($plantId !== null) {
        $stmt->bind_param('i', $plantId);
    }
    $stmt->execute();
    $users = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
    foreach ($users as &$user) {
        normalizePlantUser($user);
    }
    return $users;
}

try {
    $db = db($config);
    $admin = requireNucleiAdmin($db);
    $action = $_GET['action'] ?? '';

    switch ($action) {
        case 'all_plant_users':
            $users = listPlantUsers($db);
            respond([
                'success' => true,
                'total' => count($users),
                'users' => $users,
            ]);

        case 'plant_users':
            $plantId = (int) ($_GET['plant_id'] ?? 0);
            $plant = fetchPlant($db, $plantId);
            if (!$plant) {
                respond(['success' => false, 'message' => 'Select a valid active plant.'], 404);
            }

            $users = listPlantUsers($db, $plantId);
            respond([
                'success' => true,
                'plant' => $plant,
                'total' => count($users),
                'users' => $users,
            ]);

        case 'create_plant_login':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                respond(['success' => false, 'message' => 'POST is required.'], 405);
            }

            $input = requestBody();
            $plantId = (int) ($input['plant_id'] ?? 0);
            $name = trim((string) ($input['name'] ?? ''));
            $email = strtolower(trim((string) ($input['email'] ?? '')));
            $password = (string) ($input['password'] ?? '');
            $phone = trim((string) ($input['phone'] ?? ''));

            $plant = fetchPlant($db, $plantId);
            if (!$plant) {
                respond(['success' => false, 'message' => 'Select a valid active plant.'], 422);
            }
            if (strlen($name) < 2) {
                respond(['success' => false, 'message' => 'Enter the login user name.'], 422);
            }
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                respond(['success' => false, 'message' => 'Enter a valid login email address.'], 422);
            }
            if (strlen($password) < 8) {
                respond(['success' => false, 'message' => 'Password must contain at least 8 characters.'], 422);
            }

            $stmt = $db->prepare("SELECT id FROM users WHERE email=? LIMIT 1");
            $stmt->bind_param('s', $email);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                respond(['success' => false, 'message' => 'A user with this email already exists.'], 409);
            }

            $passwordHash = password_hash($password, PASSWORD_DEFAULT);
            $companyId = (int) $plant['company_id'];
            $phoneValue = $phone !== '' ? $phone : null;
            $stmt = $db->prepare(
                "INSERT INTO users
                    (company_id,plant_id,name,email,phone,password_hash,role,is_active)
                 VALUES (?,?,?,?,?,?,'plant_user',1)"
            );
            $stmt->bind_param(
                'iissss',
                $companyId,
                $plantId,
                $name,
                $email,
                $phoneValue,
                $passwordHash
            );
            $stmt->execute();

            $newUserId = (int) $stmt->insert_id;
            error_log(
                sprintf(
                    'Plant login %d created for plant %d by NUCLEI admin %d',
                    $newUserId,
                    $plantId,
                    $admin['id']
                )
            );

            respond([
                'success' => true,
                'message' => 'Plant login created successfully.',
                'user' => [
                    'id' => $newUserId,
                    'company_id' => $companyId,
                    'plant_id' => $plantId,
                    'name' => $name,
                    'email' => $email,
                    'phone' => $phoneValue,
                    'role' => 'plant_user',
                    'plant_name' => $plant['plant_name'],
                    'company_name' => $plant['company_name'],
                    'is_active' => true,
                ],
            ], 201);

        case 'update_plant_login':
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                respond(['success' => false, 'message' => 'POST is required.'], 405);
            }

            $input = requestBody();
            $userId = (int) ($input['user_id'] ?? 0);
            $plantId = (int) ($input['plant_id'] ?? 0);
            $name = trim((string) ($input['name'] ?? ''));
            $email = strtolower(trim((string) ($input['email'] ?? '')));
            $phone = trim((string) ($input['phone'] ?? ''));
            $password = (string) ($input['password'] ?? '');
            $isActive = !empty($input['is_active']) ? 1 : 0;

            if ($userId <= 0) {
                respond(['success' => false, 'message' => 'Select a valid user account.'], 422);
            }

            $stmt = $db->prepare(
                "SELECT id FROM users WHERE id=? AND role='plant_user' LIMIT 1"
            );
            $stmt->bind_param('i', $userId);
            $stmt->execute();
            if (!$stmt->get_result()->fetch_assoc()) {
                respond(['success' => false, 'message' => 'Plant user account was not found.'], 404);
            }

            $plant = fetchPlant($db, $plantId);
            if (!$plant) {
                respond(['success' => false, 'message' => 'Select a valid active plant.'], 422);
            }
            if (strlen($name) < 2) {
                respond(['success' => false, 'message' => 'Enter the login user name.'], 422);
            }
            if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
                respond(['success' => false, 'message' => 'Enter a valid login email address.'], 422);
            }
            if ($password !== '' && strlen($password) < 8) {
                respond(['success' => false, 'message' => 'New password must contain at least 8 characters.'], 422);
            }

            $stmt = $db->prepare("SELECT id FROM users WHERE email=? AND id<>? LIMIT 1");
            $stmt->bind_param('si', $email, $userId);
            $stmt->execute();
            if ($stmt->get_result()->fetch_assoc()) {
                respond(['success' => false, 'message' => 'Another user already uses this email address.'], 409);
            }

            $companyId = (int) $plant['company_id'];
            $phoneValue = $phone !== '' ? $phone : null;

            if ($password !== '') {
                $passwordHash = password_hash($password, PASSWORD_DEFAULT);
                $stmt = $db->prepare(
                    "UPDATE users
                     SET company_id=?,plant_id=?,name=?,email=?,phone=?,password_hash=?,is_active=?,
                         auth_token=NULL,token_created_at=NULL
                     WHERE id=? AND role='plant_user'"
                );
                $stmt->bind_param(
                    'iissssii',
                    $companyId,
                    $plantId,
                    $name,
                    $email,
                    $phoneValue,
                    $passwordHash,
                    $isActive,
                    $userId
                );
            } else {
                $stmt = $db->prepare(
                    "UPDATE users
                     SET company_id=?,plant_id=?,name=?,email=?,phone=?,is_active=?,
                         auth_token=NULL,token_created_at=NULL
                     WHERE id=? AND role='plant_user'"
                );
                $stmt->bind_param(
                    'iisssii',
                    $companyId,
                    $plantId,
                    $name,
                    $email,
                    $phoneValue,
                    $isActive,
                    $userId
                );
            }
            $stmt->execute();

            error_log(
                sprintf(
                    'Plant login %d updated by NUCLEI admin %d',
                    $userId,
                    $admin['id']
                )
            );

            respond([
                'success' => true,
                'message' => 'Plant login updated successfully.',
            ]);

        default:
            respond(['success' => false, 'message' => 'Unknown admin action.'], 404);
    }
} catch (mysqli_sql_exception $error) {
    error_log('Admin API SQL error: ' . $error->getMessage());
    respond(['success' => false, 'message' => 'A database operation failed.'], 500);
} catch (Throwable $error) {
    error_log('Admin API error: ' . $error->getMessage());
    respond(['success' => false, 'message' => 'An unexpected server error occurred.'], 500);
}
