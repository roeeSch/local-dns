#!/bin/bash

# Real-time monitoring script for the local DNS service
# Shows live updates of device status and IP changes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICES_CONF="$SCRIPT_DIR/devices.conf"
LOG_FILE="$SCRIPT_DIR/log/update_device_ips.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to clear screen and show header
show_header() {
    clear
    echo -e "${BLUE}=== Local DNS Service Monitor ===${NC}"
    echo "Updated: $(date)"
    echo "Press Ctrl+C to exit"
    echo
}

# Function to show device status
show_device_status() {
    echo -e "${YELLOW}=== Device Status ===${NC}"
    
    if [ ! -f "$DEVICES_CONF" ]; then
        echo -e "${RED}✗ devices.conf not found${NC}"
        return
    fi
    
    while read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Parse line: MAC:HOSTNAME:DESCRIPTION
        # Use a more robust parsing method
        local mac=$(echo "$line" | cut -d: -f1-6)  # MAC address (first 6 parts)
        local hostname=$(echo "$line" | cut -d: -f7)  # Hostname (7th part)
        local description=$(echo "$line" | cut -d: -f8-)  # Description (8th part onwards)
        
        # Try to discover current IP via arp-scan
        local discovered_ip=$(sudo arp-scan --localnet 2>/dev/null | grep -i "$mac" | awk '{print $1}')
        
        if [ -n "$discovered_ip" ]; then
            echo -e "${GREEN}✓${NC} $hostname ($description) - IP: $discovered_ip"
        else
            echo -e "${RED}✗${NC} $hostname ($description) - OFFLINE"
        fi
        
    done < "$DEVICES_CONF"
    echo
}

# Function to show recent log entries
show_recent_logs() {
    echo -e "${YELLOW}=== Recent Activity ===${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        tail -10 "$LOG_FILE" | while read line; do
            if [[ "$line" == *"Updated"* ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" == *"ERROR"* ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo "No log file found"
    fi
    echo
}

# Function to show DNS queries (if dnsmasq logging is enabled)
show_dns_queries() {
    echo -e "${YELLOW}=== Recent DNS Queries ===${NC}"
    
    local dns_log="$SCRIPT_DIR/log/dnsmasq.log"
    if [ -f "$dns_log" ]; then
        tail -5 "$dns_log" | grep -E "(query|reply)" | while read line; do
            echo "$line"
        done
    else
        echo "DNS query logging not available"
    fi
    echo
}

# Main monitoring loop
main() {
    # Handle Ctrl+C gracefully
    trap 'echo -e "\n${BLUE}Monitoring stopped.${NC}"; exit 0' SIGINT
    
    while true; do
        show_header
        show_device_status
        show_recent_logs
        show_dns_queries
        
        echo -e "${BLUE}Refreshing in 10 seconds...${NC}"
        sleep 10
    done
}

# Check if arp-scan is available
if ! command -v arp-scan >/dev/null 2>&1; then
    echo -e "${RED}Error: arp-scan not found. Please install it first.${NC}"
    echo "On Ubuntu/Debian: sudo apt-get install arp-scan"
    exit 1
fi

# Start monitoring
main
