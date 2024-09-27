server {
    server_name jellyfinn.mooo.com;

    # Security / XSS Mitigation Headers
    # NOTE: X-Frame-Options may cause issues with the webOS app
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "0"; # Do NOT enable. This is obsolete/dangerous
    add_header X-Content-Type-Options "nosniff";

    # Content Security Policy
    # See: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
    # Enforces https content and restricts JS/CSS to origin
    # External Javascript (such as cast_sender.js for Chromecast) must be whitelisted.
    # NOTE: The default CSP headers may cause issues with the webOS app
    add_header Content-Security-Policy "default-src https: data: blob: ; img-src 'self' https://* ; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' https://www.gstatic.com https://www.youtube.com blob:; worker-src 'self' blob:; connect-src 'self'; object-src 'none'; frame-ancestors 'self'";

    # Jellyfin
    location /jellyfin {
        return 302 $scheme://$host/jellyfin/;
    }

    # The / at the end is significant.
    # https://www.acunetix.com/blog/articles/a-fresh-look-on-reverse-proxy-related-attacks/
    location /jellyfin/ {
        # Proxy main Jellyfin traffic
        proxy_pass http://192.168.191.1:8096/;
        proxy_pass_request_headers on;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $http_connection;

        # Disable buffering when the nginx proxy gets very resource heavy upon streaming
        proxy_buffering off;
    }

    location /jellyfin/socket {
        # Proxy Jellyfin Websockets traffic
        proxy_pass http://192.168.191.1:8096/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Protocol $scheme;
        proxy_set_header X-Forwarded-Host $http_host;
    }

    listen [::]:443 ssl ipv6only=on; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/jellyfinn.mooo.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/jellyfinn.mooo.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = jellyfinn.mooo.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    listen [::]:80;

    server_name jellyfinn.mooo.com;
    return 404; # managed by Certbot
}