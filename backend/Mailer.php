<?php
declare(strict_types=1);

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

function sendAppEmail(array $config, string $to, string $subject, string $html): bool
{
    if ($to === '') {
        return false;
    }

    $smtp = $config['smtp'] ?? [];
    if (!($smtp['enabled'] ?? false)) {
        error_log("Email disabled: {$subject} -> {$to}");
        return false;
    }

    $autoload = __DIR__ . '/vendor/autoload.php';
    if (!file_exists($autoload)) {
        error_log('PHPMailer is not installed. Run composer install in backend/.');
        return false;
    }

    require_once $autoload;

    try {
        $mail = new PHPMailer(true);
        $mail->isSMTP();
        $mail->Host = (string) $smtp['host'];
        $mail->SMTPAuth = true;
        $mail->Username = (string) $smtp['username'];
        $mail->Password = (string) $smtp['password'];
        $mail->Port = (int) $smtp['port'];
        $mail->CharSet = 'UTF-8';

        $encryption = strtolower((string) ($smtp['encryption'] ?? 'tls'));
        if ($encryption === 'ssl') {
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_SMTPS;
        } elseif ($encryption === 'tls') {
            $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        }

        $mail->setFrom(
            (string) $config['mail_from_address'],
            (string) $config['mail_from_name']
        );
        $mail->addAddress($to);
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body = $html;
        $mail->AltBody = trim(strip_tags(str_replace(['<br>', '<br/>', '<br />'], "\n", $html)));
        $mail->send();
        return true;
    } catch (Exception $error) {
        error_log('Email delivery failed: ' . $error->getMessage());
        return false;
    }
}

function emailLayout(string $title, string $body): string
{
    return '<!doctype html><html><body style="margin:0;background:#f4f8ff;font-family:Arial,sans-serif;color:#172033">'
        . '<div style="max-width:640px;margin:30px auto;background:#fff;border-radius:16px;overflow:hidden;border:1px solid #d8e6fa">'
        . '<div style="background:#0b5ed7;color:#fff;padding:24px"><div style="font-size:13px;letter-spacing:1.8px">NUCLEI TECH</div>'
        . '<h1 style="margin:8px 0 0;font-size:24px">' . htmlspecialchars($title) . '</h1></div>'
        . '<div style="padding:26px;line-height:1.6">' . $body . '</div>'
        . '<div style="padding:18px 26px;background:#f4f8ff;color:#5b6b82;font-size:12px">Automated plant support notification from NUCLEI TECH.</div>'
        . '</div></body></html>';
}
