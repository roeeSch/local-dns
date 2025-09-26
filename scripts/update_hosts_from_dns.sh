#!/usr/bin/env bash

set -euo pipefail

# Paths
PROJECT_DIR="/home/roee/docker/local-dns"
GENERATED_DIR="$PROJECT_DIR/dnsmasq/generated"
HOSTS_FILE="/etc/hosts"
MARK_START="# BEGIN local-dns managed"
MARK_END="# END local-dns managed"

# Collect entries from generated dnsmasq files
collect_entries() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        return 0
    fi
    # Output in format: "IP hostname"
    grep -hE "^address=/.*?/.*$" "$dir"/*.conf 2>/dev/null | \
    awk -F'/' '{print $3" "$2}' | \
    awk 'NF==2 {print $0}' | \
    sort -u
}

# Build managed block content
build_block() {
    echo "$MARK_START"
    collect_entries "$GENERATED_DIR"
    echo "$MARK_END"
}

# Install/Update block in /etc/hosts atomically
update_hosts() {
    local tmp
    tmp=$(mktemp)
    # Read existing hosts and strip previous managed block if present
    if [ -f "$HOSTS_FILE" ]; then
        awk -v start="$MARK_START" -v end="$MARK_END" '
            $0==start {inblock=1; next}
            $0==end {inblock=0; next}
            !inblock {print $0}
        ' "$HOSTS_FILE" > "$tmp"
    fi

    # Append fresh managed block
    build_block >> "$tmp"

    # Move into place
    install -m 0644 "$tmp" "$HOSTS_FILE"
    rm -f "$tmp"
}

update_hosts
echo "Updated $HOSTS_FILE from $GENERATED_DIR"


