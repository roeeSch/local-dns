#!/bin/bash

# Multi-device IP update script for dnsmasq
# Reads device configurations and automatically updates DNS entries

DEVICES_CONF="/data/devices.conf"
DNSMASQ_CONF_DIR="/etc/dnsmasq.d"
LOGFILE="/data/update_device_ips.log" # Log to persistent data directory
SLEEP_INTERVAL=60               # seconds between checks
MAX_RETRIES=3                   # max retries for arp-scan

# Function to log messages to file and stdout
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    echo "$message" # To addon logs
    echo "$message" >> "$LOGFILE" # To file
}

# Function to discover IP for a MAC address
discover_ip() {
    local mac="$1"
    local retries=0

    while [ $retries -lt $MAX_RETRIES ]; do
        # Run arp-scan without sudo
        local ip=$(arp-scan --localnet 2>/dev/null | grep -i "$mac" | awk '{print $1}')
        if [ -n "$ip" ]; then
            echo "$ip"
            return 0
        fi
        retries=$((retries + 1))
        sleep 2
    done

    return 1
}

# Function to get current IP from dnsmasq config
get_current_ip() {
    local hostname="$1"
    local conf_file="$DNSMASQ_CONF_DIR/${hostname%%.*}.conf"

    if [ -f "$conf_file" ]; then
        grep "$hostname" "$conf_file" 2>/dev/null | awk -F/ '{print $3}'
    fi
}

# Function to update dnsmasq config for a device
update_device_config() {
    local mac="$1"
    local hostname="$2"
    local description="$3"
    local new_ip="$4"

    local conf_file="$DNSMASQ_CONF_DIR/${hostname%%.*}.conf"
    local current_ip=$(get_current_ip "$hostname")

    if [ "$current_ip" != "$new_ip" ]; then
        echo "address=/$hostname/$new_ip" > "$conf_file"
        log_message "Updated $hostname ($description) -> $new_ip (was: ${current_ip:-'not found'})"
        return 0
    fi

    return 1
}

# Function to reload dnsmasq
reload_dnsmasq() {
    local dnsmasq_pid=$(pidof dnsmasq)
    if [ -n "$dnsmasq_pid" ]; then
        kill -HUP $dnsmasq_pid
        log_message "Reloaded dnsmasq (PID: $dnsmasq_pid)"
        return 0
    else
        log_message "ERROR: dnsmasq not running, cannot reload"
        return 1
    fi
}

# Main function
main() {
    log_message "Starting multi-device IP auto-update loop"

    # The run.sh script already checks for this, but we'll leave it as a safeguard.
    if [ ! -f "$DEVICES_CONF" ]; then
        log_message "ERROR: $DEVICES_CONF not found"
        exit 1
    fi

    # Check if arp-scan is available
    if ! command -v arp-scan >/dev/null 2>&1; then
        log_message "ERROR: arp-scan not found"
        exit 1
    fi

    while true; do
        local config_updated=false
        local devices_found=0
        local devices_updated=0

        # Read devices configuration
        while read -r line; do
            # Skip empty lines and comments
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi

            # Parse line: MAC:HOSTNAME:DESCRIPTION
            local mac=$(echo "$line" | cut -d: -f1-6)
            local hostname=$(echo "$line" | cut -d: -f7)
            local description=$(echo "$line" | cut -d: -f8-)

            # Basic validation
            if [ -z "$mac" ] || [ -z "$hostname" ]; then
                log_message "Skipping invalid line: $line"
                continue
            fi

            devices_found=$((devices_found + 1))

            # Discover current IP
            local current_ip=$(discover_ip "$mac")

            if [ -z "$current_ip" ]; then
                log_message "Device not found: $hostname ($description) - MAC: $mac"
            else
                # Update configuration if IP changed
                if update_device_config "$mac" "$hostname" "$description" "$current_ip"; then
                    config_updated=true
                    devices_updated=$((devices_updated + 1))
                fi
            fi

        done < "$DEVICES_CONF"

        # Reload dnsmasq if any configuration was updated
        if [ "$config_updated" = true ]; then
            reload_dnsmasq
        fi

        # Log summary every 10 cycles (10 minutes with default interval)
        if [ $(( $(date +%s) % 600 )) -lt $SLEEP_INTERVAL ]; then
            log_message "Status: $devices_found devices configured, $devices_updated updated this cycle"
        fi

        sleep $SLEEP_INTERVAL
    done
}

# Handle signals gracefully
trap 'log_message "Received signal, shutting down gracefully"; exit 0' SIGTERM SIGINT

# Start main loop
main
