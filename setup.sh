#!/bin/sh
sudo apt-get update && sudo apt-get upgrade -y
curl -O https://raw.githubusercontent.com/angristan/openvpn-install/master/openvpn-install.sh
sudo apt-get install netfilter-persistent -y
chmod +x openvpn-install.sh
export AUTO_INSTALL=y
./openvpn-install.sh
sudo iptables -A INPUT -p udp --dport 1194 -j ACCEPT
sudo netfilter-persistent save
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join 632ea29085af566a
sudo apt-get install nginx -y
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
sudo apt-get install squid -y
sudo iptables -A INPUT -p udp --dport 3128 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 3129 -j ACCEPT
sudo netfilter-persistent save
sudo apt install apache2-utils -y
sudo snap install --classic certbot
sudo certbot --nginx -d jellyfinn.mooo.com --non-interactive --agree-tos --email joellovesa380@gmail.com
# sudo certbot certonly --standalone -d jellyfinn.mooo.com --non-interactive --agree-tos --email joellovesa380@gmail.com
sudo chown proxy:proxy /etc/letsencrypt/live/jellyfinn.mooo.com/fullchain.pem
sudo chown proxy:proxy /etc/letsencrypt/live/jellyfinn.mooo.com/privkey.pem
# curl <URL> | sudo tee /etc/squid/squid.conf > /dev/null
# curl <URL> | sudo tee /etc/nginx/sites-available/jellyfinn.mooo.com > /dev/null
sudo htpasswd -c /etc/squid/passwords joel
mkdir openvpnconfigs
sudo apt-get install acl
setfacl -Rdm www-data:rwx ./openvpnconfigs/
setfacl -Rm www-data:rwx ./openvpnconfigs/
setfacl -m www-data:rwx /home/ubuntu
mv *.ovpn ./openvpnconfigs/



# Ports to allow 1194/udp 3128/tcp 3129/tcp 80/tcp 443/tcp http://jellyfinn.mooo.com/
