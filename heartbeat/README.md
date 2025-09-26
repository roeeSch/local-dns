Heartbeat service (MQTT)
========================

This container publishes periodic MQTT heartbeats and resolves the broker hostname via the shared dnsmasq-generated configs first.

Config (.env)
-------------

Create `heartbeat/.env` (see `.env.example`):

```
MQTT_BROKER=homeassistant.local
MQTT_USERNAME=your_user
MQTT_PASSWORD=your_pass
MQTT_TOPIC=minipc/heartbeat
HEARTBEAT_INTERVAL=60
```

Runtime behavior
----------------
- Reads `/shared/dns-configs/*.conf` (bind of `../dnsmasq/generated`) to resolve `MQTT_BROKER`.
- Falls back to system DNS if not present.
- Publishes `alive` every `HEARTBEAT_INTERVAL` seconds.


