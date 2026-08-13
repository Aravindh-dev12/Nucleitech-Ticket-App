<?php
declare(strict_types=1);

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

/**
 * Removes internal SCADA identifiers from customer/support email output.
 * The SCADA ID remains available inside the application/database where needed.
 */
function sanitizeEmailHtml(string $html): string
{
    $cleaned = preg_replace(
        '~<tr>\s*<td[^>]*>\s*<strong>\s*SCADA ID\s*</strong>.*?</tr>~is',
        '',
        $html
    );

    return is_string($cleaned) ? $cleaned : $html;
}

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

        $safeHtml = sanitizeEmailHtml($html);
        $mail->Body = $safeHtml;
        $mail->AltBody = trim(
            strip_tags(
                str_replace(
                    ['<br>', '<br/>', '<br />'],
                    "\n",
                    $safeHtml
                )
            )
        );

        $mail->send();
        return true;
    } catch (Exception $error) {
        error_log('Email delivery failed: ' . $error->getMessage());
        return false;
    }
}

function emailLayout(string $title, string $body): string
{
    $safeTitle = htmlspecialchars($title, ENT_QUOTES, 'UTF-8');

    return '<!doctype html>'
        . '<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head>'
        . '<body style="margin:0;padding:0;background:#eef4fb;font-family:Arial,Helvetica,sans-serif;color:#172033">'
        . '<div style="display:none;max-height:0;overflow:hidden;color:transparent">NUCLEI TECH ticket update</div>'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;background:#eef4fb;border-collapse:collapse">'
        . '<tr><td align="center" style="padding:30px 14px">'
        . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="width:100%;max-width:720px;background:#ffffff;border:1px solid #d8e6fa;border-radius:18px;overflow:hidden;border-collapse:separate">'
        . '<tr><td style="padding:26px 30px;background:#0b5ed7;color:#ffffff">'
        . '<div style="font-size:12px;line-height:1.2;letter-spacing:2.2px;font-weight:800;color:#dceaff">NUCLEI TECH</div>'
        . '<div style="margin-top:8px;font-size:26px;line-height:1.25;font-weight:800;color:#ffffff">' . $safeTitle . '</div>'
        . '<div style="margin-top:8px;font-size:13px;line-height:1.5;color:#dceaff">Plant Support &amp; Ticket Management</div>'
        . '</td></tr>'
        . '<tr><td style="padding:30px;font-size:14px;line-height:1.7;color:#172033">'
        . $body
        . '<div style="margin-top:26px;padding:14px 16px;background:#f4f8fd;border:1px solid #dce8f7;border-radius:10px;color:#52647a;font-size:12px;line-height:1.6">'
        . '<strong style="color:#23405f">NUCLEI TECH Support</strong><br>'
        . 'This message is part of the official ticket workflow. Open the NUCLEI TECH app for ticket history, images, replies and current status.'
        . '</div>'
        . '</td></tr>'
        . '<tr><td style="padding:18px 30px;background:#f8fbff;border-top:1px solid #e4edf8;color:#718096;font-size:11px;line-height:1.6">'
        . 'Automated support notification from NUCLEI TECH. Please keep the ticket number when contacting support.'
        . '</td></tr>'
        . '</table>'
        . '</td></tr></table>'
        . '</body></html>';
}
