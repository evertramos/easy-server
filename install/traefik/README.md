# Traefik Reverse Proxy

Production-ready Traefik v3 setup with automatic HTTPS, TLS hardening and Cloudflare integration.

## Features

- Automatic HTTPS with Let's Encrypt (ACME)
- DNS-01 challenge support (Cloudflare, Bunny)
- HTTP-01 challenge support
- TLS 1.2+ with strong ciphers (SSL Labs A+ ready)
- HTTP to HTTPS automatic redirect
- Dashboard with Basic Auth and IP whitelist
- Cloudflare Tunnel support
- JSON logging for ELK/Graylog ingestion

## Directory Structure

```
traefik/
├── conf/
│   ├── traefik.yml      # Main static configuration
│   └── dynamic.yml      # Dynamic TLS configuration
├── data/
│   ├── acme.json        # ACME certificates (chmod 600)
│   └── logs/            # Access logs
├── bin/
│   └── gen-password     # Generate htpasswd hash
├── docker-compose.yml
├── .env.example
└── install-traefik      # Installation script
```

## Installation

### 1. Run the install script

```bash
# Install to /opt/traefik (default)
./install-traefik

# Or specify a custom base directory
./install-traefik /srv
```

### 2. Configure environment variables

```bash
sudo vi /opt/traefik/.env
```

Required variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `DASHBOARD_DOMAIN` | Domain for Traefik dashboard | `traefik.example.com` |
| `DASHBOARD_USER` | Basic auth credentials (htpasswd format) | `admin:$$2y$$05$$...` |
| `WHITELIST_IPS` | Allowed IPs for dashboard | `192.168.1.0/24,10.0.0.1` |
| `CF_DNS_API_TOKEN` | Cloudflare API Token (DNS challenge) | `your-token` |
| `TUNNEL_TOKEN` | Cloudflare Tunnel token (optional) | `your-tunnel-token` |

### 3. Generate dashboard password

```bash
cd /opt/traefik
./bin/gen-password admin

# Output:
# Generated hash:
# admin:$2y$05$...
#
# For .env file (escape $ with $$):
# admin:$$2y$$05$$...
```

Copy the escaped version (with `$$`) to your `.env` file.

### 4. Start Traefik

```bash
cd /opt/traefik
sudo docker compose up -d
```

## Configuration

### Certificate Resolvers

Three resolvers are pre-configured:

| Resolver | Challenge | Use Case |
|----------|-----------|----------|
| `cloudflare` | DNS-01 | Wildcard certs, servers behind firewall |
| `bunny` | DNS-01 | Bunny.net DNS users |
| `http01` | HTTP-01 | Simple setup, port 80 required |

### TLS Options

Two TLS profiles are available in `dynamic.yml`:

| Profile | Min Version | Use Case |
|---------|-------------|----------|
| `default` | TLS 1.2 | Compatible with most browsers |
| `strict` | TLS 1.3 | Maximum security |

To use the strict profile on a service:

```yaml
labels:
  - "traefik.http.routers.myapp.tls.options=strict@file"
```

### Entry Points

| Name | Port | Description |
|------|------|-------------|
| `web` | 80 | HTTP (redirects to HTTPS) |
| `websecure` | 443 | HTTPS |

## Adding Services

Example service with Traefik labels:

```yaml
services:
  myapp:
    image: myapp:latest
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=Host(`myapp.example.com`)"
      - "traefik.http.routers.myapp.entrypoints=websecure"
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"

networks:
  proxy:
    external: true
```

## Environment Variables Reference

### Cloudflare DNS Challenge

```bash
# Option 1: API Token (recommended)
# Required permission: Zone:DNS:Edit
CF_DNS_API_TOKEN=your-api-token

# Option 2: Global API Key (less secure)
CF_API_EMAIL=your-email@example.com
CF_API_KEY=your-global-api-key
```

### Bunny DNS Challenge

```bash
BUNNY_API_KEY=your-bunny-api-key
```

## Logs

Access logs are stored in `/opt/traefik/data/logs/access.log` in JSON format.

By default, only errors (status 400-599) are logged. To log all requests, edit `traefik.yml`:

```yaml
accessLog:
  filters:
    statusCodes:
      - "200-599"
```

## Troubleshooting

### Check Traefik logs

```bash
docker logs traefik -f
```

### Verify certificate issuance

```bash
docker exec traefik cat /acme.json | jq
```

### Test TLS configuration

```bash
# Using SSL Labs
https://www.ssllabs.com/ssltest/

# Using testssl.sh
docker run --rm -it drwetter/testssl.sh https://your-domain.com
```

### Common issues

1. **Certificate not issued**: Check DNS propagation and API token permissions
2. **Dashboard not accessible**: Verify `WHITELIST_IPS` includes your IP
3. **503 Service Unavailable**: Ensure the service is on the `proxy` network

## Security Recommendations

1. Keep `acme.json` with permissions `600`
2. Use strong passwords for dashboard (generated with bcrypt)
3. Restrict dashboard access with IP whitelist
4. Use Cloudflare Tunnel for additional security layer
5. Regularly update Traefik image
