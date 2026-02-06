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
│   ├── certs/           # Cloudflare Origin Certificates
│   │   ├── origin.pem   # Certificate (you provide)
│   │   └── origin.key   # Private key (you provide)
│   └── logs/            # Access logs
├── bin/
│   ├── gen-password     # Generate htpasswd hash
│   └── whoami           # Test Traefik routing
├── docker-compose.yml
├── .env.example
└── install-traefik      # Installation script
```

## Prerequisites

```bash
# Add your user to the docker group (logout/login required)
sudo usermod -aG docker $USER

# Verify
docker ps
```

> **Note**: After installation, all `docker compose` commands can be run without `sudo`.

## Installation

### 1. Run the install script

```bash
# Install to /opt/traefik (default)
./install-traefik

# Or specify a custom directory
./install-traefik /srv
```

The script will set proper ownership for your user.

### 2. Configure environment variables

```bash
vi /opt/traefik/.env
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

### Certificate Resolvers (ACME)

Three resolvers are pre-configured for automatic certificate issuance:

| Resolver | Challenge | Use Case |
|----------|-----------|----------|
| `cloudflare` | DNS-01 | Wildcard certs, servers behind firewall |
| `bunny` | DNS-01 | Bunny.net DNS users |
| `le` | HTTP-01 | Simple setup, port 80 required |

### Cloudflare Origin Certificate (Recommended for Tunnel)

When using Cloudflare Tunnel, Origin Certificates are the best option:
- **15-year validity** - no renewal needed
- **No API tokens required** - simpler setup
- **End-to-end encryption** - between Cloudflare and your origin

#### Setup

1. **Create the certificate** in Cloudflare Dashboard:
   - Go to **SSL/TLS > Origin Server**
   - Click **Create Certificate**
   - Choose **Let Cloudflare generate a private key**
   - Add your domains (e.g., `*.example.com`, `example.com`)
   - Select validity (15 years recommended)
   - Click **Create**

2. **Save the certificate files**:
   ```bash
   # Save the certificate (PEM format)
   vi /opt/traefik/data/certs/origin.pem

   # Save the private key
   vi /opt/traefik/data/certs/origin.key

   # Set permissions
   chmod 600 /opt/traefik/data/certs/origin.key
   ```

3. **Enable in dynamic.yml**:
   ```yaml
   tls:
     certificates:
       - certFile: /etc/traefik/certs/origin.pem
         keyFile: /etc/traefik/certs/origin.key

     stores:
       default:
         defaultCertificate:
           certFile: /etc/traefik/certs/origin.pem
           keyFile: /etc/traefik/certs/origin.key
   ```

4. **Update service labels** (remove certresolver):
   ```yaml
   labels:
     - "traefik.http.routers.myapp.tls=true"
     # Remove: traefik.http.routers.myapp.tls.certresolver=cloudflare
   ```

5. **Restart Traefik**:
   ```bash
   docker compose restart traefik
   ```

> **Note**: Origin Certificates are only trusted by Cloudflare. Direct access to your server (bypassing Cloudflare) will show certificate warnings. This is expected and adds security.

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
| `metrics` | 8080 | Prometheus metrics (internal only) |

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
      # Option A: ACME (Let's Encrypt)
      - "traefik.http.routers.myapp.tls.certresolver=cloudflare"
      # Option B: Origin Certificate (uncomment and remove certresolver)
      # - "traefik.http.routers.myapp.tls=true"

networks:
  proxy:
    external: true
```

When using Origin Certificate with `defaultCertificate` configured, you only need `tls=true` - the default certificate will be used automatically.

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

## Testing with Whoami

Use the whoami script to validate Traefik routing and TLS:

```bash
# Configure the test domain
cp bin/whoami.env.example bin/whoami.env
vi bin/whoami.env

# Start the test container
./bin/whoami up

# Test the endpoint
./bin/whoami test

# View logs
./bin/whoami logs

# Clean up when done
./bin/whoami down
```

The whoami container returns request details (headers, IP, hostname) - useful for validating:
- TLS certificate issuance
- X-Forwarded-For headers from Cloudflare
- Routing rules

## Prometheus Metrics

Metrics are exposed on the internal `metrics` entrypoint (`:8080`) and can be scraped by Prometheus at `http://traefik:8080/metrics`.

For a complete monitoring setup with Prometheus, Grafana, and Alertmanager, see `../monitoring/`.

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
