FROM debian:bookworm

# Install packages
RUN apt-get update && \
    apt-get install -y dnsmasq arp-scan && \
    apt-get clean

# Copy configs and scripts
COPY ./dnsmasq/dnsmasq.conf /etc/dnsmasq.conf
COPY ./dnsmasq/update_nvr_ip.sh /etc/dnsmasq.d/update_nvr_ip.sh
RUN chmod +x /etc/dnsmasq.d/update_nvr_ip.sh

# Start dnsmasq and the update script
CMD ["bash", "-c", "dnsmasq -k -C /etc/dnsmasq.conf & bash /etc/dnsmasq.d/update_nvr_ip.sh"]
