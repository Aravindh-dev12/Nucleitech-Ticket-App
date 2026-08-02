<?php
declare(strict_types=1);

$config = require __DIR__ . '/config.php';

$db = new mysqli(
    $config['db_host'],
    $config['db_user'],
    $config['db_password'],
    $config['db_name'],
    (int) $config['db_port']
);

if ($db->connect_errno) {
    fwrite(STDERR, "Database connection failed: {$db->connect_error}\n");
    exit(1);
}

$db->set_charset('utf8mb4');
$db->begin_transaction();

try {
    $companyStmt = $db->prepare(
        "INSERT INTO companies (company_code, company_name)
         VALUES (?, ?)
         ON DUPLICATE KEY UPDATE company_name = VALUES(company_name), is_active = 1"
    );

    $companiesToSeed = [
        ['VJ', 'Vijayanth'],
        ['VS', 'Vinoba Solar'],
    ];

    foreach ($companiesToSeed as [$code, $name]) {
        $companyStmt->bind_param('ss', $code, $name);
        $companyStmt->execute();
    }

    $companies = [];
    $result = $db->query("SELECT id, company_code FROM companies");
    while ($row = $result->fetch_assoc()) {
        $companies[$row['company_code']] = (int) $row['id'];
    }

    $websocketUrl = 'wss://vinobasolar.scadahub.in:5001';
    $subscriptionPayload = json_encode([
        'action' => 'subscribe',
        'siteId' => '{{site_id}}',
    ], JSON_UNESCAPED_SLASHES);

    // Display capacity and SCADA site ID are intentionally separate.
    $plantsToSeed = [
        ['VJ', 'VJ-SRN-1MW', 'SRN', 'SRI Ram Nallamani Blue Metals', 1.00, 'via-4mw'],
        ['VJ', 'VJ-VCP-7MW', 'VCP', 'Vijayanth Cosmic Powers Pvt Ltd', 7.00, 'via7mw'],
        ['VJ', 'VJ-KPF-3MW', 'KPF', 'Krishna Poultry Farm', 3.00, 'via3mw'],
        ['VJ', 'VJ-BTJ-4MW', 'BTJ', 'Bojaraj Textiles Pvt Ltd', 4.00, 'via-1mw'],
        ['VS', 'VS-ANUSHYAM', 'ANU', 'Anushyam Solar Pvt Ltd', null, 'anushyam'],
        ['VS', 'VS-MAKKAL', 'MAK', 'MakkalPower Pvt Ltd', null, 'Makkalpower'],
        ['VS', 'VS-VELLIYANAI', 'VSP', 'Vinoba Solar Pvt Ltd', null, 'vinoba-velliyanai'],
    ];

    $plantStmt = $db->prepare(
        "INSERT INTO plants
            (company_id, plant_code, ticket_prefix, plant_name, capacity_mw, scada_site_id,
             websocket_url, subscription_payload, scada_enabled, is_active)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, 1)
         ON DUPLICATE KEY UPDATE
            ticket_prefix = VALUES(ticket_prefix),
            plant_name = VALUES(plant_name),
            capacity_mw = VALUES(capacity_mw),
            scada_site_id = VALUES(scada_site_id),
            websocket_url = VALUES(websocket_url),
            subscription_payload = VALUES(subscription_payload),
            scada_enabled = 1,
            is_active = 1"
    );

    foreach ($plantsToSeed as [$companyCode, $plantCode, $ticketPrefix, $plantName, $capacity, $siteId]) {
        $companyId = $companies[$companyCode];
        $plantStmt->bind_param(
            'isssdsss',
            $companyId,
            $plantCode,
            $ticketPrefix,
            $plantName,
            $capacity,
            $siteId,
            $websocketUrl,
            $subscriptionPayload
        );
        $plantStmt->execute();
    }

    $db->query(
        "INSERT INTO ticket_counters (plant_id, next_sequence)
         SELECT id, 1 FROM plants
         ON DUPLICATE KEY UPDATE next_sequence = GREATEST(next_sequence, VALUES(next_sequence))"
    );

    $userStmt = $db->prepare(
        "INSERT INTO users
            (company_id, plant_id, name, email, password_hash, role, is_active)
         VALUES (?, NULL, ?, ?, ?, ?, 1)
         ON DUPLICATE KEY UPDATE
            company_id = VALUES(company_id),
            plant_id = NULL,
            name = VALUES(name),
            password_hash = VALUES(password_hash),
            role = VALUES(role),
            is_active = 1"
    );

    $usersToSeed = [
        [null, 'NUCLEI TECH Owner', 'nfo.nucleitech@gmail.com',
            getenv('NUCLEI_OWNER_PASSWORD') ?: 'Admin@123', 'nuclei_admin'],
        [$companies['VJ'], 'Vijayanth Admin', 'vijayanth@scada.com',
            getenv('VIJAYANTH_PASSWORD') ?: 'vijayanth@123', 'company_admin'],
        [$companies['VS'], 'Vinoba Solar Admin', 'vinobasolar@scada.com',
            getenv('VINOBA_PASSWORD') ?: 'vinoba@123', 'company_admin'],
    ];

    foreach ($usersToSeed as [$companyId, $name, $email, $password, $role]) {
        $passwordHash = password_hash($password, PASSWORD_DEFAULT);
        $userStmt->bind_param(
            'issss',
            $companyId,
            $name,
            $email,
            $passwordHash,
            $role
        );
        $userStmt->execute();
    }

    $db->commit();

    echo "Seed completed successfully.\n";
    echo "NUCLEI TECH owner: nfo.nucleitech@gmail.com / Admin@123\n";
    echo "Vijayanth: vijayanth@scada.com / vijayanth@123\n";
    echo "Vinoba Solar: vinobasolar@scada.com / vinoba@123\n";
} catch (Throwable $error) {
    $db->rollback();
    fwrite(STDERR, "Seed failed: {$error->getMessage()}\n");
    exit(1);
}
