# NUCLEI TECH API

Base URL:

```text
/api.php?action=ACTION
```

Protected endpoints require:

```http
Authorization: Bearer USER_TOKEN
```

## Authentication

- `POST action=login`
- `POST action=logout`
- `GET action=me`

## Plants and SCADA

- `GET action=plants`
- `GET action=scada_config&plant_id=ID`
- `GET action=scada_snapshot&plant_id=ID`
- `POST action=save_scada_snapshot`

Example SCADA configuration response:

```json
{
  "success": true,
  "config": {
    "plant_id": 1,
    "site_id": "via-4mw",
    "websocket_url": "wss://vinobasolar.scadahub.in:5001",
    "subscription_payload": {
      "action": "subscribe",
      "siteId": "{{site_id}}"
    },
    "enabled": true
  }
}
```

## Tickets

- `GET action=tickets`
- `GET action=ticket&id=ID`
- `POST action=create_ticket` using `multipart/form-data`
- `POST action=add_comment`
- `POST action=update_status` (support roles only)

## Notifications

- `GET action=notifications`
- `POST action=mark_notification_read`
- `POST action=register_device`
