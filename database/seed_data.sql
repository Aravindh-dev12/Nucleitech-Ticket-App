-- NUCLEI TECH starter data, release 2.1.0
-- Import schema.sql first.

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
  (company_id, plant_code, plant_name, capacity_mw, scada_site_id,
   websocket_url, subscription_payload, scada_enabled, is_active)
VALUES
  (@vj_company_id, 'VJ-SRN-1MW', 'SRI Ram Nallamani Blue Metals', 1.00,
   'via-4mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-VCP-7MW', 'Vijayanth Cosmic Powers Pvt Ltd', 7.00,
   'via7mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-KPF-3MW', 'Krishna Poultry Farm', 3.00,
   'via3mw', @ws_url, @subscription, 1, 1),
  (@vj_company_id, 'VJ-BTJ-4MW', 'Bojaraj Textiles Pvt Ltd', 4.00,
   'via-1mw', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-ANUSHYAM', 'Anushyam Solar Pvt Ltd', NULL,
   'anushyam', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-MAKKAL', 'MakkalPower Pvt Ltd', NULL,
   'Makkalpower', @ws_url, @subscription, 1, 1),
  (@vs_company_id, 'VS-VELLIYANAI', 'Vinoba Solar Pvt Ltd', NULL,
   'vinoba-velliyanai', @ws_url, @subscription, 1, 1)
ON DUPLICATE KEY UPDATE
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

COMMIT;
