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
curl -O https://raw.githubusercontent.com/angristan/wireguard-install/refs/heads/master/wireguard-install.sh
chmod +x ./wireguard-install.sh
sudo ./wireguard-install.sh
# Allow wireguard through firewall
sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
# Save all iptables rules
sudo netfilter-persistent save
# Start wireguard
sudo systemctl enable wg-quick@wg0.service

###############
# Client to run
###############

output_for_gw_and_interface=$(ip route list table main default)

# Extract the gateway and interface from the output
gateway=$(echo "$output_for_gw_and_interface" | grep -oP '(?<=via )\S+')
interface=$(echo "$output_for_gw_and_interface" | grep -oP '(?<=dev )\S+')

output_for_inteface_ip=$(ip -brief address show $interface)

# Extract the first IPv4 address
ip_of_interface=$(echo "$output_for_inteface_ip" | grep -oP '\b\d{1,3}(\.\d{1,3}){3}\b' | head -n 1)

cat <<EOL >> /etc/wireguard/wg0.conf

PostUp = ip rule add table 200 from $ip_of_interface
PostUp = ip route add table 200 default via $gateway
PreDown = ip rule delete table 200 from $ip_of_interface
PreDown = ip route delete table 200 default via $gateway
EOL
# Ports to allow 1194/udp 3128/tcp 3129/tcp 80/tcp 443/tcp 2112/tcp
