FROM debian:bookworm

# Install packages
RUN apt-get update && \
    apt-get install -y dnsmasq arp-scan && \
    apt-get clean

# Create dnsmasq directory
RUN mkdir -p /etc/dnsmasq.d

# Start dnsmasq and the update script
CMD ["bash", "-c", "dnsmasq -k -C /etc/dnsmasq.conf & bash /etc/dnsmasq.d/update_device_ips.sh"]
