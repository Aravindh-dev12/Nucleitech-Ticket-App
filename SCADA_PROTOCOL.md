# SCADA WebSocket Adapter

## Current endpoint

```text
wss://vinobasolar.scadahub.in:5001
```

## Exact production site IDs

```text
via-4mw
via7mw
via3mw
via-1mw
anushyam
Makkalpower
vinoba-velliyanai
```

Do not add spaces to these values. `via3mw` is the normalized production value for Krishna Poultry Farm.

## Default subscription

```json
{"action":"subscribe","siteId":"{{site_id}}"}
```

The PHP API replaces no values itself. It sends the template to Flutter; Flutter replaces `{{site_id}}` before transmitting it to the WebSocket.

## Supported incoming structures

The normalizer accepts:

- Root JSON objects
- Root JSON arrays
- Payloads wrapped in `data`, `payload`, `result`, or `message`
- Inverter arrays/maps under `inverter`, `inverters`, or `inv`
- Breaker arrays/maps under `vcb`, `vcbs`, `breaker`, or `breakers`

The Raw JSON viewer should be used for the first real connection. If the vendor uses different names, update alias arrays in `frontend/lib/services/scada_service.dart`.
