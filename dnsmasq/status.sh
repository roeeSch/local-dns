#!/bin/bash

# Status script for the local DNS service
# Shows current device configurations and their IP addresses
# Works both inside and outside Docker container

# Detect if running inside container or on host
if [ -f "/etc/dnsmasq.d/devices.conf" ]; then
    # Running inside container
    DEVICES_CONF="/etc/dnsmasq.d/devices.conf"
    DNSMASQ_CONF_DIR="/etc/dnsmasq.d"
    LOG_DIR="/var/log"
else
    # Running on host
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    DEVICES_CONF="$SCRIPT_DIR/devices.conf"
    DNSMASQ_CONF_DIR="$SCRIPT_DIR"
    LOG_DIR="$SCRIPT_DIR/log"
fi

echo "=== Local DNS Service Status ==="
echo "Generated: $(date)"
echo

# Check if dnsmasq is running
if pidof dnsmasq >/dev/null; then
    echo "✓ dnsmasq is running (PID: $(pidof dnsmasq))"
else
    echo "✗ dnsmasq is not running"
fi
echo

# Check if devices.conf exists
if [ -f "$DEVICES_CONF" ]; then
    echo "=== Configured Devices ==="
    echo "MAC Address          | Hostname        | Description"
    echo "---------------------|-----------------|------------------"
    
    while read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Parse line: MAC:HOSTNAME:DESCRIPTION
        local mac=$(echo "$line" | cut -d: -f1-6)  # MAC address (first 6 parts)
        local hostname=$(echo "$line" | cut -d: -f7)  # Hostname (7th part)
        local description=$(echo "$line" | cut -d: -f8-)  # Description (8th part onwards)
        
        # Get current IP from dnsmasq config
        local conf_file="$DNSMASQ_CONF_DIR/${hostname%%.*}.conf"
        local current_ip="not found"
        
        if [ -f "$conf_file" ]; then
            current_ip=$(grep "$hostname" "$conf_file" 2>/dev/null | awk -F/ '{print $3}')
        fi
        
        # Try to discover current IP via arp-scan
        local discovered_ip=$(sudo arp-scan --localnet 2>/dev/null | grep -i "$mac" | awk '{print $1}')
        
        if [ -n "$discovered_ip" ]; then
            if [ "$current_ip" = "$discovered_ip" ]; then
                status="✓"
            else
                status="⚠"
            fi
            echo "$status $mac | $hostname | $description (IP: $discovered_ip)"
        else
            echo "✗ $mac | $hostname | $description (offline)"
        fi
        
    done < "$DEVICES_CONF"
else
    echo "✗ devices.conf not found at $DEVICES_CONF"
fi

echo
echo "=== DNS Configuration Files ==="
if [ -d "$DNSMASQ_CONF_DIR" ]; then
    for conf_file in "$DNSMASQ_CONF_DIR"/*.conf; do
        if [ -f "$conf_file" ] && [ "$(basename "$conf_file")" != "devices.conf" ]; then
            echo "File: $(basename "$conf_file")"
            cat "$conf_file" | sed 's/^/  /'
            echo
        fi
    done
else
    echo "✗ dnsmasq configuration directory not found"
fi

echo "=== Recent Log Entries ==="
if [ -f "$LOG_DIR/update_device_ips.log" ]; then
    tail -5 "$LOG_DIR/update_device_ips.log" | sed 's/^/  /'
else
    echo "  No log file found at $LOG_DIR/update_device_ips.log"
fi
