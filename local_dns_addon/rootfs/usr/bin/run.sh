#!/usr/bin/with-contenv bash

echo "### Local DNS Service Addon Starting ###"

# Check if user has created the devices.conf file
if [ ! -f /data/devices.conf ]; then
    echo "-----------------------------------------------------------"
    echo "ERROR: devices.conf not found in the addon's /data/ directory."
    echo "Please create this file and add your devices."
    echo "You can do this via the Samba addon, VSCode addon,"
    echo "or by enabling SSH access to the host."
    echo "The addon will not start without this file."
    echo "-----------------------------------------------------------"
    exit 1
fi

# Start dnsmasq
echo "Starting dnsmasq..."
dnsmasq --keep-in-foreground --log-facility=- --conf-file=/etc/dnsmasq.conf &
DNSMASQ_PID=$!

# Start the update script
echo "Starting IP update script..."
/usr/bin/update_device_ips.sh &
UPDATE_PID=$!

# Graceful shutdown handler
function shutdown() {
    echo "Received shutdown signal. Stopping services..."
    kill -TERM "$UPDATE_PID"
    kill -TERM "$DNSMASQ_PID"
    wait "$UPDATE_PID"
    wait "$DNSMASQ_PID"
    echo "Services stopped. Exiting."
    exit 0
}

trap shutdown SIGTERM SIGINT

# Wait for either process to exit, and handle shutdown
wait -n $DNSMASQ_PID $UPDATE_PID
# If we reach here, one of the processes died unexpectedly.
# Trigger shutdown to clean up the other one.
shutdown
