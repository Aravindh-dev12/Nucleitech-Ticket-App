# START HERE — NUCLEI TECH 2.1.0

## Correct Vijayanth SCADA IDs

| Plant | Capacity | SCADA ID |
|---|---:|---|
| SRI Ram Nallamani Blue Metals | 1 MW | `via-4mw` |
| Vijayanth Cosmic Powers Pvt Ltd | 7 MW | `via7mw` |
| Krishna Poultry Farm | 3 MW | `via3mw` |
| Bojaraj Textiles Pvt Ltd | 4 MW | `via-1mw` |

## New installation

1. Import `database/schema.sql`.
2. Configure `backend/config.php`.
3. Run `php backend/seed.php`.
4. Run `frontend/setup_frontend.sh` or `frontend/setup_frontend.bat`.
5. Set the API URL in `frontend/lib/config.dart`.
6. Start PHP and Flutter.

## Existing installation

Run `database/update_scada_ids_v2.sql`, then restart the backend and app.

## Theme

The frontend uses a white background with NUCLEI TECH blue headers, buttons, active controls and light-blue card/form accents.
