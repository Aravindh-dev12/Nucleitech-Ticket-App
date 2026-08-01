<?php
declare(strict_types=1);

return [
    'db_host' => '127.0.0.1',
    'db_port' => 3306,
    'db_name' => 'nuclei_tech',
    'db_user' => 'root',
    'db_password' => '',

    // Public URL of this backend, without a trailing slash.
    'app_url' => 'http://localhost:8080',
    'allowed_origins' => ['*'],

    'owner_email' => 'nfo.nucleitech@gmail.com',
    'mail_from_name' => 'NUCLEI TECH Support',
    'mail_from_address' => 'nfo.nucleitech@gmail.com',

    // Set enabled=true and use a Gmail App Password for real delivery.
    'smtp' => [
        'enabled' => false,
        'host' => 'smtp.gmail.com',
        'port' => 587,
        'encryption' => 'tls',
        'username' => 'nfo.nucleitech@gmail.com',
        'password' => 'PUT_GMAIL_APP_PASSWORD_HERE',
    ],

    'max_image_bytes' => 10 * 1024 * 1024,
    'max_images_per_ticket' => 6,
    'upload_directory' => __DIR__ . '/uploads',
];
