CREATE DATABASE IF NOT EXISTS nuclei_tech_ticket
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE nuclei_tech_ticket;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS scada_snapshots;
DROP TABLE IF EXISTS device_tokens;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS ticket_history;
DROP TABLE IF EXISTS ticket_comments;
DROP TABLE IF EXISTS ticket_attachments;
DROP TABLE IF EXISTS tickets;
DROP TABLE IF EXISTS ticket_counters;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS plants;
DROP TABLE IF EXISTS companies;

CREATE TABLE companies (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_code VARCHAR(20) NOT NULL UNIQUE,
    company_name VARCHAR(150) NOT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE plants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NOT NULL,
    plant_code VARCHAR(50) NOT NULL,
    ticket_prefix VARCHAR(12) NOT NULL,
    plant_name VARCHAR(180) NOT NULL,
    capacity_mw DECIMAL(8,2) NULL,
    scada_site_id VARCHAR(100) NOT NULL,
    websocket_url VARCHAR(500) NOT NULL,
    subscription_payload JSON NULL,
    scada_enabled TINYINT(1) NOT NULL DEFAULT 1,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_company_plant_code (company_id, plant_code),
    UNIQUE KEY uq_company_scada_site (company_id, scada_site_id),
    UNIQUE KEY uq_plants_ticket_prefix (ticket_prefix),
    CONSTRAINT fk_plants_company FOREIGN KEY (company_id) REFERENCES companies(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ticket_counters (
    plant_id BIGINT UNSIGNED PRIMARY KEY,
    next_sequence BIGINT UNSIGNED NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_counters_plant FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_id BIGINT UNSIGNED NULL,
    plant_id BIGINT UNSIGNED NULL,
    name VARCHAR(150) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    phone VARCHAR(30) NULL,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('company_admin','plant_user','support_engineer','nuclei_admin') NOT NULL,
    auth_token VARCHAR(128) NULL UNIQUE,
    token_created_at DATETIME NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_users_plant FOREIGN KEY (plant_id) REFERENCES plants(id),
    INDEX idx_users_company (company_id),
    INDEX idx_users_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tickets (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_number VARCHAR(80) NOT NULL UNIQUE,
    ticket_sequence BIGINT UNSIGNED NOT NULL,
    company_id BIGINT UNSIGNED NOT NULL,
    plant_id BIGINT UNSIGNED NOT NULL,
    raised_by BIGINT UNSIGNED NOT NULL,
    assigned_to BIGINT UNSIGNED NULL,
    category VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
    status ENUM('open','assigned','in_progress','waiting_for_user','on_hold','resolved','closed','reopened','cancelled') NOT NULL DEFAULT 'open',
    resolution_notes TEXT NULL,
    resolved_at DATETIME NULL,
    closed_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_tickets_company FOREIGN KEY (company_id) REFERENCES companies(id),
    CONSTRAINT fk_tickets_plant FOREIGN KEY (plant_id) REFERENCES plants(id),
    CONSTRAINT fk_tickets_raised_by FOREIGN KEY (raised_by) REFERENCES users(id),
    CONSTRAINT fk_tickets_assigned_to FOREIGN KEY (assigned_to) REFERENCES users(id),
    INDEX idx_tickets_company (company_id),
    INDEX idx_tickets_plant (plant_id),
    UNIQUE KEY uq_tickets_plant_sequence (plant_id, ticket_sequence),
    INDEX idx_tickets_status (status),
    INDEX idx_tickets_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ticket_attachments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL,
    uploaded_by BIGINT UNSIGNED NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    stored_name VARCHAR(255) NOT NULL,
    file_url VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_attachments_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_attachments_user FOREIGN KEY (uploaded_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ticket_comments (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL,
    user_id BIGINT UNSIGNED NOT NULL,
    comment TEXT NOT NULL,
    is_internal TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_comments_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_comments_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE ticket_history (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id BIGINT UNSIGNED NOT NULL,
    changed_by BIGINT UNSIGNED NOT NULL,
    action VARCHAR(100) NOT NULL,
    old_value TEXT NULL,
    new_value TEXT NULL,
    notes TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_history_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_history_user FOREIGN KEY (changed_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    ticket_id BIGINT UNSIGNED NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(50) NOT NULL,
    is_read TINYINT(1) NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_notifications_ticket FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE,
    INDEX idx_notifications_user_read (user_id, is_read)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE device_tokens (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    platform ENUM('android','ios','web','windows') NOT NULL,
    device_token TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_device_tokens_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_device_tokens_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE scada_snapshots (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    plant_id BIGINT UNSIGNED NOT NULL,
    payload_json JSON NOT NULL,
    received_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_scada_snapshots_plant FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE,
    INDEX idx_scada_snapshots_plant_received (plant_id, received_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- Starter data: companies, plants, SCADA subscriptions and login accounts.
-- This section makes schema.sql a complete one-file installation.

START TRANSACTION;

INSERT INTO companies (company_code, company_name, is_active)
VALUES
  ('VJ', 'Vijayanth', 1),
  ('VS', 'Vinoba Solar', 1)
ON DUPLICATE KEY UPDATE
  company_name = VALUES(company_name),
  is_active = 1;

SET @vj_company_id = (SELECT id FROM companies WHERE company_code = 'VJ' LIMIT 1);
SET @vs_company_id = (SELECT id FROM companies WHERE company_code = 'VS' LIMIT 1);
SET @ws_url = 'wss://vinobasolar.scadahub.in:5001';
SET @subscription = JSON_OBJECT('action', 'subscribe', 'siteId', '{{site_id}}');

INSERT INTO plants
  (company_id, plant_code, ticket_prefix, plant_name, capacity_mw, scada_site_id,
   websocket_url, subscription_payload, scada_enabled, is_active)
VALUES
  (@vj_company_id, 'VJ-SRN-1MW', 'SRN', 'SRI Ram Nallamani Blue Metals', 1.00,
   'via-4mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-VCP-7MW', 'VCP', 'Vijayanth Cosmic Powers Pvt Ltd', 7.00,
   'via7mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-KPF-3MW', 'KPF', 'Krishna Poultry Farm', 3.00,
   'via3mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-BTJ-4MW', 'BTJ', 'Bojaraj Textiles Pvt Ltd', 4.00,
   'via-1mw', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-ANUSHYAM', 'ANU', 'Anushyam Solar Pvt Ltd', NULL,
   'anushyam', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-MAKKAL', 'MAK', 'MakkalPower Pvt Ltd', NULL,
   'Makkalpower', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-VELLIYANAI', 'VSP', 'Vinoba Solar Pvt Ltd', NULL,
   'vinoba-velliyanai', @ws_url, @subscription, 1, 1)
ON DUPLICATE KEY UPDATE
  ticket_prefix = VALUES(ticket_prefix),
  plant_name = VALUES(plant_name),
  capacity_mw = VALUES(capacity_mw),
  scada_site_id = VALUES(scada_site_id),
  websocket_url = VALUES(websocket_url),
  subscription_payload = VALUES(subscription_payload),
  scada_enabled = 1,
  is_active = 1;

INSERT INTO users
  (company_id, plant_id, name, email, password_hash, role, is_active)
VALUES
  (NULL, NULL, 'NUCLEI TECH Owner', 'nfo.nucleitech@gmail.com',
   '$2y$12$1tH6hW7QfEa8gRhBwOCE2uM99vwrhtLmYzILF.pIbJdcCO0xvjkJu', 'nuclei_admin', 1),
  (@vj_company_id, NULL, 'Vijayanth Admin', 'vijayanth@scada.com',
   '$2y$12$sXyvDkd26ZwJOqzsqpr10OmHbM41zOHKaIDErSmC2/1k21xrUGwsq', 'company_admin', 1),
  (@vs_company_id, NULL, 'Vinoba Solar Admin', 'vinobasolar@scada.com',
   '$2y$12$hdDqKezpiWijFlfvGieODe/i4wORf733l3Wslu5MdEj7Ft/ETUZdK', 'company_admin', 1)
ON DUPLICATE KEY UPDATE
  company_id = VALUES(company_id),
  plant_id = VALUES(plant_id),
  name = VALUES(name),
  password_hash = VALUES(password_hash),
  role = VALUES(role),
  is_active = 1;

INSERT INTO ticket_counters (plant_id, next_sequence)
SELECT id, 1 FROM plants
ON DUPLICATE KEY UPDATE
  next_sequence = GREATEST(next_sequence, VALUES(next_sequence));

COMMIT;
