import paho.mqtt.client as mqtt
import time
import os
import sys
import socket
import subprocess
import glob

def resolve_from_generated(hostname: str, directory: str = "/shared/dns-configs"):
    try:
        for path in glob.glob(f"{directory}/*.conf"):
            try:
                with open(path, "r") as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith("#"):
                            continue
                        if line.startswith("address=/"):
                            parts = line.split("/")
                            if len(parts) == 3:
                                host = parts[1]
                                ip = parts[2]
                                if host == hostname and ip:
                                    print(f"Resolved {hostname} to {ip} via generated configs: {path}")
                                    return ip
            except Exception:
                pass
    except Exception:
        pass
    return None

def resolve_hostname(hostname):
    ip = resolve_from_generated(hostname)
    if ip:
        return ip
    try:
        ip = socket.gethostbyname(hostname)
        print(f"Resolved {hostname} to {ip}")
        return ip
    except socket.gaierror:
        try:
            result = subprocess.run(['nslookup', hostname], capture_output=True, text=True, timeout=5)
            if result.returncode == 0:
                for line in result.stdout.split('\n'):
                    if 'Address:' in line and not '#' in line:
                        ip = line.split('Address:')[1].strip()
                        if ip and ip != '127.0.0.1':
                            print(f"Resolved {hostname} to {ip} via nslookup")
                            return ip
        except Exception:
            pass
        print(f"Could not resolve {hostname}, using hostname directly")
        return hostname

broker_hostname = os.getenv("MQTT_BROKER", "your_broker_ip_or_hostname")
broker = resolve_hostname(broker_hostname)
username = os.getenv("MQTT_USERNAME", "your_mqtt_username")
password = os.getenv("MQTT_PASSWORD", "your_mqtt_password")
topic = os.getenv("MQTT_TOPIC", "minipc/heartbeat")
interval = int(os.getenv("HEARTBEAT_INTERVAL", "60"))

print(f"Connecting to MQTT broker: {broker} (original: {broker_hostname})")
print(f"Topic: {topic}")
print(f"Interval: {interval} seconds")
print("Starting heartbeat loop...", flush=True)

client = mqtt.Client()
client.username_pw_set(username, password)

try:
    client.connect(broker, 1883, 60)
    print("Connected to MQTT broker successfully")
except Exception as e:
    print(f"Failed to connect to MQTT broker: {e}")
    sys.exit(1)

while True:
    try:
        client.publish(topic, "alive")
        print(f"Published heartbeat to {topic}", flush=True)
    except Exception as e:
        print(f"Failed to publish heartbeat: {e}", flush=True)
    time.sleep(interval)


