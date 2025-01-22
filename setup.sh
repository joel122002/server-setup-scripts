#!/bin/sh
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install netfilter-persistent -y
# Download openvpn installation script
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
chmod +x openvpn-install.sh
# Run openvpn installation script headlessly
sudo AUTO_INSTALL=y APPROVE_INSTALL=y APPROVE_IP=y IPV6_SUPPORT=n PORT_CHOICE=1 PROTOCOL_CHOICE=1 COMPRESSION_ENABLED=n DNS=9 ENDPOINT=$(curl -4 ifconfig.me) CUSTOMIZE_ENC=n CLIENT=client ./openvpn-install.sh
# Create a folder to store all openvpn config files
mkdir openvpnconfigs
# Move all openvpn config files to the config folder
mv *.ovpn ./openvpnconfigs/
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
sudo netfilter-persistent save
# Install and join zerotier newtork
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join 632ea29085af566a
# Install and configure nginx
sudo apt-get install nginx -y
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
curl https://raw.githubusercontent.com/joel122002/server-setup-scripts/refs/heads/main/jellyfinn.mooo.com | sudo tee /etc/nginx/sites-available/jellyfinn.mooo.com >/dev/null
sudo ln -s /etc/nginx/sites-available/jellyfinn.mooo.com /etc/nginx/sites-enabled/
# Install and configure squid
sudo apt-get install squid -y
sudo iptables -A INPUT -p tcp --dport 3128 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3129 -j ACCEPT
sudo netfilter-persistent save
curl https://raw.githubusercontent.com/joel122002/server-setup-scripts/refs/heads/main/squid.conf | sudo tee /etc/squid/squid.conf >/dev/null
# Install certbot for requesting SSL certificates
sudo snap install --classic certbot
sudo certbot --nginx -d jellyfinn.mooo.com --non-interactive --agree-tos --email joellovesa380@gmail.com
# Allow squid access to the certificates
sudo chown proxy:proxy /etc/letsencrypt/live/jellyfinn.mooo.com/fullchain.pem
sudo chown proxy:proxy /etc/letsencrypt/live/jellyfinn.mooo.com/privkey.pem
# Install htpasswd for generating hashed passwords
sudo apt install apache2-utils -y
# Create squid user with the username "joel"
sudo htpasswd -c /etc/squid/passwords joel
# Install acl for giving granular permission control of folders to specific users
sudo apt-get install acl
# Give nginx access to serve openvpn config files
setfacl -Rdm www-data:rwx ./openvpnconfigs/
setfacl -Rm www-data:rwx ./openvpnconfigs/
setfacl -m www-data:rwx /home/ubuntu
# Update ssh config to allow reverse SSH
curl https://raw.githubusercontent.com/joel122002/server-setup-scripts/refs/heads/main/sshd_config | sudo tee /etc/ssh/sshd_config >/dev/null
sudo systemctl restart ssh
# Allow reverse SSH port
sudo iptables -A INPUT -p tcp --dport 2112 -j ACCEPT
# Install wireguard
sudo apt install wireguard
# Create wireguard priv key and set permission only to root
wg genkey | sudo tee /etc/wireguard/private.key
sudo chmod go= /etc/wireguard/private.key
# Derive public key from priv key
sudo cat /etc/wireguard/private.key | wg pubkey | sudo tee /etc/wireguard/public.key
privkey=$(sudo cat /etc/wireguard/private.key)
pubkey=$(cat /etc/wireguard/public.key)
# Deriving ipv6 subnet

# Generate a timestamp with nanoseconds
timestamp=$(date +%s%N)
# Read the machine-id from the system
machine_id=$(cat /var/lib/dbus/machine-id)
# Combine timestamp and machine-id, then hash with SHA-1
hash=$(printf "%s%s" "$timestamp" "$machine_id" | sha1sum | awk '{print $1}')
# Extract the last 5 bytes of the hash
last_5_bytes=$(printf "%s" "$hash" | cut -c 31-)
# Convert the 5 bytes into the IPv6 format (fd prefix)
ipv6_prefix="fd"
ipv6_bytes=$(echo "$last_5_bytes" | sed -r 's/(..)(..)(..)(..)(..)/\1:\2:\3:\4:\5/')
# Construct the IPv6 address
ipv6_address="$ipv6_prefix:$ipv6_bytes::/64"
# Wirte to the config file
cat <<EOL > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $privkey
Address = 10.8.0.1/24, $ipv6_address
ListenPort = 51820
SaveConfig = true
EOL

# Allow IPv4 and IPv6 forwarding

# File path to sysctl.conf
sysctl_conf="/etc/sysctl.conf"

# Uncomment the required lines and handle optional spaces around the '=' sign
sed -i '/^#\s*net\.ipv4\.ip_forward\s*=\s*1/s/^#\s*//' "$sysctl_conf"
sed -i '/^#\s*net\.ipv6\.conf\.all\.forwarding\s*=\s*1/s/^#\s*//' "$sysctl_conf"

# Reload new values for current terminal session
sudo sysctl -p

# Get adapter to route traffic through 
adapter=$(ip route list default | awk '/default/ {for (i=1; i<=NF; i++) if ($i == "dev") print $(i+1)}')

cat <<EOL >> /etc/wireguard/wg0.conf
PostUp = ufw route allow in on wg0 out on $adapter
PostUp = iptables -t nat -I POSTROUTING -o $adapter -j MASQUERADE
PostUp = ip6tables -t nat -I POSTROUTING -o $adapter -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on $adapter
PreDown = iptables -t nat -D POSTROUTING -o $adapter -j MASQUERADE
PreDown = ip6tables -t nat -D POSTROUTING -o $adapter -j MASQUERADE
EOL

# Allow wireguard through firewall
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
# Save all iptables rules
sudo netfilter-persistent save
# Start wireguard
sudo systemctl enable wg-quick@wg0.service

# Ports to allow 1194/udp 3128/tcp 3129/tcp 80/tcp 443/tcp 2112/tcp
