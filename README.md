# Local DNS Service - MAC to IP Mapping

A Docker-based DNS service that automatically maps MAC addresses to hostnames in your local network. This is perfect when you can't configure your router's DNS settings but want to access devices by name instead of IP addresses.

## Features

- **Automatic IP Discovery**: Uses `arp-scan` to discover device IP addresses
- **Dynamic DNS Updates**: Automatically updates DNS entries when devices change IP
- **Multiple Device Support**: Configure multiple devices with their MAC addresses and hostnames
- **Real-time Monitoring**: Monitor device status and DNS queries
- **Docker-based**: Easy deployment and management
- **No Router Configuration**: Works without modifying router settings

## Quick Start

1. **Configure your devices** in `dnsmasq/devices.conf`:
   ```
   ec:71:db:bd:12:08:nvr.home:NVR Camera System
   aa:bb:cc:dd:ee:ff:printer.home:HP LaserJet Printer
   ```

2. **Build and start the service**:
   ```bash
   docker-compose up -d
   ```

3. **Check status**:
   ```bash
   ./dnsmasq/status.sh
   ```

4. **Monitor in real-time**:
   ```bash
   ./dnsmasq/monitor.sh
   ```

## Configuration

### Device Configuration

Edit `dnsmasq/devices.conf` to add your devices:

```
# Format: MAC_ADDRESS:HOSTNAME:DESCRIPTION
ec:71:db:bd:12:08:nvr.home:NVR Camera System
aa:bb:cc:dd:ee:ff:printer.home:HP LaserJet Printer
11:22:33:44:55:66:nas.home:Synology NAS
```

### DNS Configuration

The main dnsmasq configuration is in `dnsmasq/dnsmasq.conf`. Key settings:

- **Interface**: Set to your LAN interface (e.g., `enp3s0`)
- **Upstream DNS**: Uses Google DNS (8.8.8.8, 8.8.4.4)
- **Logging**: Enabled for monitoring

## Usage

### Adding Devices

1. Find your device's MAC address:
   ```bash
   arp-scan --localnet | grep "device_ip"
   ```

2. Add to `dnsmasq/devices.conf`:
   ```
   MAC_ADDRESS:hostname.home:Device Description
   ```

3. Restart the service:
   ```bash
   docker-compose restart
   ```

### Accessing Devices

Once configured, you can access devices by hostname:

```bash
# Instead of: http://192.168.1.100
# Use: http://nvr.home

ping nvr.home
ssh user@nas.home
```

### Monitoring

**Check Status**:
```bash
./dnsmasq/status.sh
```

**Real-time Monitoring**:
```bash
./dnsmasq/monitor.sh
```

**View Logs**:
```bash
tail -f dnsmasq/log/update_device_ips.log
```

## Network Configuration

### Client DNS Setup

Configure your devices to use this DNS server:

**Linux**:
```bash
# Edit /etc/resolv.conf
nameserver YOUR_SERVER_IP
```

**Windows**:
- Network Settings → Change adapter options → Properties → IPv4 → DNS

**Router DHCP** (if possible):
- Set this server as the primary DNS server in DHCP settings

### Firewall

Ensure the DNS service is accessible:

```bash
# Allow DNS traffic (port 53)
sudo ufw allow 53/udp
sudo ufw allow 53/tcp
```

## Troubleshooting

### Device Not Found

1. **Check MAC address**:
   ```bash
   arp-scan --localnet | grep "device_ip"
   ```

2. **Verify device is online**:
   ```bash
   ping device_ip
   ```

3. **Check logs**:
   ```bash
   tail -f dnsmasq/log/update_device_ips.log
   ```

### DNS Not Working

1. **Check dnsmasq status**:
   ```bash
   docker-compose logs local-dns
   ```

2. **Test DNS resolution**:
   ```bash
   nslookup hostname.home YOUR_SERVER_IP
   ```

3. **Verify client DNS settings**:
   ```bash
   # Linux
   cat /etc/resolv.conf
   
   # Windows
   ipconfig /all
   ```

### Performance Issues

- **Reduce scan frequency**: Edit `SLEEP_INTERVAL` in `update_device_ips.sh`
- **Limit network scope**: Modify `arp-scan` command to scan specific subnets
- **Check network congestion**: Monitor with `monitor.sh`

## File Structure

```
local-dns/
├── docker-compose.yaml          # Docker Compose configuration
├── Dockerfile                   # Docker image definition
├── README.md                    # This file
└── dnsmasq/
    ├── dnsmasq.conf             # Main dnsmasq configuration
    ├── devices.conf             # Device MAC-to-hostname mapping
    ├── example-devices.conf     # Example device configuration
    ├── update_device_ips.sh     # Main update script
    ├── status.sh                # Status checking script
    ├── monitor.sh               # Real-time monitoring script
   # update_nvr_ip.sh         # (removed: legacy single-device script)
    └── log/                     # Log files directory
        ├── update_device_ips.log
        └── dnsmasq.log
```

## How it works end-to-end (no router changes)

- dnsmasq container discovers device IPs with `arp-scan` and writes per-host files:
  - Active files used by dnsmasq: `/etc/dnsmasq.d/<host>.conf`
  - Mirrored files for the host/other containers: `/etc/dnsmasq.d/generated/<host>.conf` (bind-mounted to `./dnsmasq/generated`)
- A host-side systemd path unit watches `./dnsmasq/generated` and updates a managed block in `/etc/hosts` via `scripts/update_hosts_from_dns.sh`.
- Linux host and other containers normally resolve via Docker’s DNS (127.0.0.11) → host resolver (systemd‑resolved at 127.0.0.53). Because `/etc/hosts` is always current, `nvr.local` (etc.) resolves without running a DNS on port 53 or editing router DHCP.
- The separate heartbeat container reads `./dnsmasq/generated/*.conf` directly, resolving hostnames even if the system resolver can’t query dnsmasq (since it listens on 5354).

Implications:
- The host will keep resolving even if the dnsmasq container is briefly down (last written IP remains in `/etc/hosts`).
- Containers like Frigate also benefit because Docker forwards DNS to the host resolver which consults `/etc/hosts`.

## Host sync setup

Install once (already included in this repo):
```bash
sudo chmod +x ./scripts/update_hosts_from_dns.sh
sudo cp ./scripts/update_hosts_from_dns.service /etc/systemd/system/
sudo cp ./scripts/update_hosts_from_dns.path /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now update_hosts_from_dns.path
sudo ./scripts/update_hosts_from_dns.sh
```
This creates/maintains a managed block in `/etc/hosts` bounded by:
```
# BEGIN local-dns managed
# END local-dns managed
```

## Heartbeat container

- Configure `../hearbeat/.env`:
```
MQTT_BROKER=homeassistant.local
MQTT_USERNAME=your_user
MQTT_PASSWORD=your_pass
MQTT_TOPIC=minipc/heartbeat
HEARTBEAT_INTERVAL=60
```
- It resolves `MQTT_BROKER` first from `/shared/dns-configs/*.conf` (the bind of `./dnsmasq/generated`), then falls back to normal DNS.

## Notes and tips

- dnsmasq uses port 5354 to avoid clashing with `systemd-resolved`; system resolvers won’t query 5354. That’s why we mirror mappings and update `/etc/hosts`.
- Ensure `dnsmasq.conf` `interface=` matches your LAN NIC (e.g., `enp3s0`) so `arp-scan` finds devices.
- To add devices, edit `dnsmasq/devices.conf` and `docker-compose restart local-dns`.

## Security Considerations

- **Network Access**: The service binds to all interfaces by default
- **ARP Scanning**: Uses `arp-scan` which requires network access
- **Log Files**: May contain sensitive network information
- **Docker Privileges**: Runs with host network access

## Advanced Configuration

### Custom DNS Settings

Edit `dnsmasq/dnsmasq.conf` to customize:

- Upstream DNS servers
- Local domain settings
- Query logging
- Interface binding

### Multiple Networks

For multiple network interfaces, modify the `arp-scan` command in `update_device_ips.sh`:

```bash
# Scan specific interface
arp-scan --interface=enp3s0 --localnet

# Scan multiple subnets
arp-scan 192.168.1.0/24 192.168.2.0/24
```
## Log Management (Automatic Log Rotation)

To prevent log files from growing indefinitely, this project includes a sample logrotate configuration (`logrotate.conf`). This will automatically rotate, compress, and clean up old log files in `dnsmasq/log/`.

### Setup

1. Ensure `logrotate` is installed on your system (most Linux distributions include it by default).
2. Use the provided `logrotate.conf` in the project root. It will:
   - Rotate any `.log` file in `dnsmasq/log/` when it reaches 10MB
   - Keep 7 compressed backups
   - Truncate logs in place (safe for running services)

### Example logrotate.conf

```conf
/home/roee/docker/local-dns/dnsmasq/log/*.log {
   size 10M
   rotate 7
   compress
   missingok
   notifempty
   copytruncate
   create 0644 root root
}
```

### Automating with cron

To run logrotate daily, add this line to your crontab (edit with `crontab -e`):

```
0 0 * * * /usr/sbin/logrotate -s /home/roee/docker/local-dns/logrotate.status /home/roee/docker/local-dns/logrotate.conf
```

This will check and rotate logs every night at midnight. The `-s` option stores logrotate's state so it knows when to rotate.

You can adjust the schedule or logrotate options as needed for your environment.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is open source. Feel free to modify and distribute as needed.
