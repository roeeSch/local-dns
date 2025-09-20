#!/bin/bash

NVR_MAC="ec:71:db:bd:12:08"       # Replace with your NVR's MAC
HOSTNAME="nvr.home"
DNSMASQ_CONF="/etc/dnsmasq.d/nvr.conf"
LOGFILE="/var/log/update_nvr_ip.log"
SLEEP_INTERVAL=60               # seconds between checks

echo "$(date): Starting NVR IP auto-update loop" >> "$LOGFILE"

while true; do
    # Discover NVR IP via arp-scan
    NVR_IP=$(arp-scan --localnet | grep -i "$NVR_MAC" | awk '{print $1}')

    if [ -z "$NVR_IP" ]; then
        echo "$(date): NVR not found" >> "$LOGFILE"
    else
        CURRENT_IP=$(grep "$HOSTNAME" "$DNSMASQ_CONF" 2>/dev/null | awk -F/ '{print $3}')
        if [ "$CURRENT_IP" != "$NVR_IP" ]; then
            echo "address=/$HOSTNAME/$NVR_IP" > "$DNSMASQ_CONF"
            echo "$(date): Updated $HOSTNAME -> $NVR_IP" >> "$LOGFILE"

            # Reload dnsmasq
            DNSMASQ_PID=$(pidof dnsmasq)
            if [ -n "$DNSMASQ_PID" ]; then
                kill -HUP $DNSMASQ_PID
            else
                echo "$(date): dnsmasq not running, cannot reload" >> "$LOGFILE"
            fi
        fi
    fi

    sleep $SLEEP_INTERVAL
done
