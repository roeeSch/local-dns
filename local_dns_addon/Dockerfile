ARG BUILD_FROM=ghcr.io/home-assistant/aarch64-base-debian:bookworm
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required packages
RUN apt-get update && \
    apt-get install -y dnsmasq arp-scan && \
    rm -rf /var/lib/apt/lists/*

# Copy root file system
COPY rootfs /
