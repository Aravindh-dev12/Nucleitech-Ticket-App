-- NUCLEI TECH SCADA ID correction, version 2.1.0
-- Run this only on an existing database created from an earlier package.

USE nuclei_tech_ticket;

START TRANSACTION;

UPDATE plants p
JOIN companies c ON c.id = p.company_id
SET p.scada_site_id = CASE p.plant_code
    WHEN 'VJ-SRN-1MW' THEN 'via-4mw'
    WHEN 'VJ-VCP-7MW' THEN 'via7mw'
    WHEN 'VJ-KPF-3MW' THEN 'via3mw'
    WHEN 'VJ-BTJ-4MW' THEN 'via-1mw'
    ELSE p.scada_site_id
END,
p.updated_at = CURRENT_TIMESTAMP
WHERE c.company_code = 'VJ'
  AND p.plant_code IN (
      'VJ-SRN-1MW',
      'VJ-VCP-7MW',
      'VJ-KPF-3MW',
      'VJ-BTJ-4MW'
  );

COMMIT;

SELECT c.company_name, p.plant_name, p.capacity_mw, p.scada_site_id
FROM plants p
JOIN companies c ON c.id = p.company_id
WHERE c.company_code = 'VJ'
ORDER BY p.capacity_mw;
