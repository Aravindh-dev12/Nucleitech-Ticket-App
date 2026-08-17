-- Change the existing NUCLEI TECH admin login without altering support email routing.
-- Password remains Admin@123 because the existing password_hash is preserved.

START TRANSACTION;

UPDATE users
SET
  name = 'NUCLEI TECH Admin',
  email = 'admin@nuclei.com',
  is_active = 1
WHERE role = 'nuclei_admin';

COMMIT;
