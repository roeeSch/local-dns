# Local DNS Service Addon for Home Assistant

This addon provides a local DNS service that automatically maps MAC addresses to hostnames on your network. It uses `arp-scan` to find devices and `dnsmasq` to resolve their names.

## How It Works

The addon periodically scans your local network to find the IP addresses of the devices you configure. When an IP address is found or changes, it updates the `dnsmasq` configuration and reloads it. This allows you to access devices on your network using stable hostnames (e.g., `nvr.local`), even if their IP addresses are assigned dynamically by your router.

## Installation

1.  **Copy the Addon to Home Assistant:**
    *   You need access to the `/addons` directory of your Home Assistant installation. The easiest way to do this is with the [Home Assistant Community Add-on: Samba](https://github.com/home-assistant/addons/blob/master/samba/README.md) or the [Home Assistant Community Add-on: SSH & Web Terminal](https://github.com/home-assistant/addons/blob/master/ssh/README.md).
    *   Copy the entire `local_dns_addon` directory into the `/addons` directory on your Home Assistant instance.

2.  **Refresh and Install:**
    *   Go to **Settings > Add-ons > Add-on Store**.
    *   Click the three dots in the top right corner and select **Check for updates**.
    *   Your new addon, "Local DNS Service," should appear under the "Local add-ons" section.
    *   Click on the addon and then click **Install**.

## Configuration

### 1. Create `devices.conf`

Before you start the addon, you **must** provide a configuration file that lists the devices you want to map.

1.  **Access the `/data` directory:** The addon needs the file in its own `/data` directory. The easiest way to create this file is using the **File editor** or **Visual Studio Code** addon in Home Assistant.
    *   Navigate to the following path: `/usr/share/hassio/addons/data/local_dns` (If you are using the VSCode addon, you might need to disable the "workspace" setting to browse the full filesystem).
    *   Create a new file named `devices.conf`.

2.  **Add Your Devices:**
    *   Open the `devices.conf` file and add your devices using the format `MAC_ADDRESS:HOSTNAME:DESCRIPTION`.
    *   The MAC address must be in lowercase.
    *   The hostname should be a simple name or a fully qualified domain name (e.g., `nvr.local`).
    *   The description is optional and is used for logging.

    **Example `devices.conf`:**
    ```
    # Format: MAC_ADDRESS:HOSTNAME:DESCRIPTION
    ec:71:db:bd:12:08:nvr.local:NVR Camera System
    2c:cf:67:b1:40:77:homeassistant.local:Home Assistant
    aa:bb:cc:dd:ee:ff:printer.local:Network Printer
    ```

### 2. Start the Addon

*   Once your `devices.conf` is in place, go to the addon's page in Home Assistant and click **Start**.
*   Check the **Logs** tab to see if the addon starts correctly. It should log that it has found your configuration file and is starting the services.

### 3. Configure Your Network's DNS

For your devices to be able to use the new hostnames, they must use your Home Assistant device as their DNS server.

1.  **Find your Home Assistant IP address.** You can find this in **Settings > System > Network**.
2.  **Log in to your router's administration page.**
3.  **Find the DHCP or LAN settings.**
4.  **Change the Primary DNS Server:** Set the primary (and preferably only) DNS server to the IP address of your Home Assistant device.
5.  **Save the settings and reboot your router.**

After your router and devices have updated their network settings, you should be able to access your configured devices using their new hostnames (e.g., `ping nvr.local`).
