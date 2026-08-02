# START HERE — NUCLEI TECH 2.1.0

## Correct Vijayanth SCADA IDs

| Plant | Ticket short ID | Capacity | SCADA ID |
|---|---|---:|---|
| SRI Ram Nallamani Blue Metals | `SRN` | 1 MW | `via-4mw` |
| Vijayanth Cosmic Powers Pvt Ltd | `VCP` | 7 MW | `via7mw` |
| Krishna Poultry Farm | `KPF` | 3 MW | `via3mw` |
| Bojaraj Textiles Pvt Ltd | `BTJ` | 4 MW | `via-1mw` |

## New installation

1. Import `database/schema.sql`; it creates the `nuclei_tech_ticket` database, tables and starter data.
2. Configure `backend/config.php`.
3. Run `frontend/setup_frontend.sh` or `frontend/setup_frontend.bat`.
4. Set the API URL in `frontend/lib/config.dart`.
5. Start PHP and Flutter.

## Existing installation

Run `database/migrate_ticket_numbering_v3.sql` once to add short plant ticket IDs and per-plant ticket counters. If needed, also run `database/update_scada_ids_v2.sql`, then restart the backend and app.

## Theme

The frontend uses a white background with NUCLEI TECH blue headers, buttons, active controls and light-blue card/form accents.
