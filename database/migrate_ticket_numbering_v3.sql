-- NUCLEI TECH ticket numbering upgrade, version 3.
-- Run this once on the existing live database.
-- It adds plant short IDs and converts ticket numbers to NT-{PLANT}-{01}.

USE nuclei_tech_ticket;

START TRANSACTION;

ALTER TABLE plants
  ADD COLUMN ticket_prefix VARCHAR(12) NULL AFTER plant_code;

UPDATE plants
SET ticket_prefix = CASE plant_code
    WHEN 'VJ-SRN-1MW' THEN 'SRN'
    WHEN 'VJ-VCP-7MW' THEN 'VCP'
    WHEN 'VJ-KPF-3MW' THEN 'KPF'
    WHEN 'VJ-BTJ-4MW' THEN 'BTJ'
    WHEN 'VS-ANUSHYAM' THEN 'ANU'
    WHEN 'VS-MAKKAL' THEN 'MAK'
    WHEN 'VS-VELLIYANAI' THEN 'VSP'
    ELSE UPPER(LEFT(REPLACE(REPLACE(REPLACE(plant_code, '-', ''), '_', ''), ' ', ''), 12))
END
WHERE ticket_prefix IS NULL OR ticket_prefix = '';

ALTER TABLE plants
  MODIFY ticket_prefix VARCHAR(12) NOT NULL,
  ADD UNIQUE KEY uq_plants_ticket_prefix (ticket_prefix);

CREATE TABLE IF NOT EXISTS ticket_counters (
    plant_id BIGINT UNSIGNED PRIMARY KEY,
    next_sequence BIGINT UNSIGNED NOT NULL DEFAULT 1,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_ticket_counters_plant FOREIGN KEY (plant_id) REFERENCES plants(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE tickets
  ADD COLUMN ticket_sequence BIGINT UNSIGNED NULL AFTER ticket_number;

SET @current_plant_id := 0;
SET @ticket_sequence := 0;

CREATE TEMPORARY TABLE ticket_sequence_backfill AS
SELECT
  ordered.id,
  ordered.plant_id,
  (@ticket_sequence := IF(@current_plant_id = ordered.plant_id, @ticket_sequence + 1, 1)) AS next_number,
  (@current_plant_id := ordered.plant_id) AS ignored
FROM (
  SELECT id, plant_id
  FROM tickets
  ORDER BY plant_id, id
) ordered;

UPDATE tickets
SET ticket_number = CONCAT('MIGRATING-', id);

UPDATE tickets t
JOIN ticket_sequence_backfill b ON b.id = t.id
JOIN plants p ON p.id = t.plant_id
SET
  t.ticket_sequence = b.next_number,
  t.ticket_number = CONCAT('NT-', p.ticket_prefix, '-', LPAD(b.next_number, 2, '0'));

DROP TEMPORARY TABLE ticket_sequence_backfill;

ALTER TABLE tickets
  MODIFY ticket_sequence BIGINT UNSIGNED NOT NULL,
  ADD UNIQUE KEY uq_tickets_plant_sequence (plant_id, ticket_sequence);

INSERT INTO ticket_counters (plant_id, next_sequence)
SELECT p.id, COALESCE(MAX(t.ticket_sequence), 0) + 1
FROM plants p
LEFT JOIN tickets t ON t.plant_id = p.id
GROUP BY p.id
ON DUPLICATE KEY UPDATE
  next_sequence = VALUES(next_sequence);

COMMIT;
