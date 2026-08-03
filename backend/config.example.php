<?php
declare(strict_types=1);

return [
    'db_host' => '127.0.0.1',
    'db_port' => 3306,
    'db_name' => 'nuclei_tech_ticket',
    'db_user' => 'root',
    'db_password' => '',

    // Public URL of this backend, without a trailing slash.
    'app_url' => 'https://YOUR_TICKET_DOMAIN',
    'allowed_origins' => ['https://YOUR_APP_DOMAIN'],

    // Manual ticket workflow mailbox. New plant tickets are delivered here.
    'owner_email' => 'info@orikscare.com',
    'mail_from_name' => 'NUCLEI TECH Support',
    'mail_from_address' => 'info@orikscare.com',

    // Configure this for the actual provider hosting info@orikscare.com.
    // Never commit the live mailbox password to GitHub.
    'smtp' => [
        'enabled' => true,
        'host' => 'smtp.example.com',
        'port' => 587,
        'encryption' => 'tls',
        'username' => 'info@orikscare.com',
        'password' => getenv('NUCLEI_SMTP_PASSWORD') ?: '',
    ],

    'max_image_bytes' => 10 * 1024 * 1024,
    'max_images_per_ticket' => 6,
    'upload_directory' => __DIR__ . '/uploads',
];
