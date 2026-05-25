# Server

PocketBase runs on internal port `8090`. Production traffic should terminate TLS
at a reverse proxy and forward requests to PocketBase over local HTTP.

## Domain

Production domain:

```text
https://www.tori-capsule.me
```

PocketBase OAuth2 redirect URI:

```text
https://www.tori-capsule.me/api/oauth2-redirect
```

Google OAuth client settings must use the exact same redirect URI.

## Run PocketBase

```bash
cd server
docker compose up -d --build
```

This container exposes PocketBase on:

```text
http://127.0.0.1:8090
```

## Nginx Reverse Proxy

An Nginx server block template is provided at:

[deploy/nginx/tori-capsule.me.conf](/Users/choyeonwoo/WorkSpace/cap3/server/deploy/nginx/tori-capsule.me.conf)

Expected flow:

1. `www.tori-capsule.me:443` receives HTTPS traffic.
2. Nginx terminates TLS.
3. Nginx proxies the request to `http://127.0.0.1:8090`.

Example symlink on the server:

```bash
sudo ln -s /path/to/cap3/server/deploy/nginx/tori-capsule.me.conf /etc/nginx/sites-enabled/tori-capsule.me.conf
```

Then validate and reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Let's Encrypt

One common setup is:

```bash
sudo certbot --nginx -d www.tori-capsule.me -d tori-capsule.me
```

The Nginx template assumes certificates are stored at:

```text
/etc/letsencrypt/live/www.tori-capsule.me/fullchain.pem
/etc/letsencrypt/live/www.tori-capsule.me/privkey.pem
```

## PocketBase Admin

Admin URL:

```text
https://www.tori-capsule.me/_/
```

## Google OAuth Checklist

Google Auth Platform client type:

```text
Web application
```

Authorized redirect URI:

```text
https://www.tori-capsule.me/api/oauth2-redirect
```

Recommended checks:

1. PocketBase admin opens at `https://www.tori-capsule.me/_/`.
2. The `users` auth collection has OAuth2 enabled.
3. The `google` provider client ID and secret are set in PocketBase.
4. Google test users include the account you are signing in with.
5. The app is using `https://www.tori-capsule.me` as its API base URL.
