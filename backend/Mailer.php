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
    return '<!doctype html><html><body style="margin:0;background:#eef4fb;font-family:Arial,Helvetica,sans-serif;color:#172033">'
        . '<div style="display:none;max-height:0;overflow:hidden">NUCLEI TECH plant ticket update</div>'
        . '<div style="max-width:720px;margin:28px auto;background:#ffffff;border:1px solid #d8e6fa">'
        . '<div style="background:#0b5ed7;color:#ffffff;padding:24px 28px">'
        . '<div style="font-size:12px;letter-spacing:2px;font-weight:700">NUCLEI TECH</div>'
        . '<h1 style="margin:8px 0 0;font-size:24px;line-height:1.25">' . htmlspecialchars($title) . '</h1>'
        . '<p style="margin:8px 0 0;color:#dceaff;font-size:13px">SCADA Monitoring and Plant Support Desk</p>'
        . '</div>'
        . '<div style="padding:28px;line-height:1.6;font-size:14px">' . $body . '</div>'
        . '<div style="padding:18px 28px;background:#f7fbff;color:#5b6b82;font-size:12px;border-top:1px solid #d8e6fa">'
        . 'This is an automated ticket report from NUCLEI TECH. Please use the app for complete history, images and replies.'
        . '</div>'
        . '</div></body></html>';
}
