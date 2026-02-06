# Monitoring Stack

Production-ready monitoring with Prometheus, Grafana, Loki, and Alertmanager. Integrates with Traefik for TLS and routing.

## Features

- **Prometheus** for metrics collection and alerting
- **Loki** for log aggregation (like Prometheus, but for logs)
- **Promtail** for collecting Docker container logs
- **Grafana** with pre-configured dashboards
- **Alertmanager** for notifications (Slack, email)
- TLS via Traefik (Let's Encrypt)
- Basic Auth protection
- Cloudflare Tunnel support

## Directory Structure

```
monitoring/
├── docker-compose.yml
├── .env.example
├── install-monitoring
├── prometheus/
│   ├── prometheus.yml    # Scrape configuration
│   └── alerts.yml        # Alert rules
├── loki/
│   └── loki.yml          # Log storage configuration
├── promtail/
│   └── promtail.yml      # Log collection configuration
├── grafana/
│   └── provisioning/
│       ├── dashboards/
│       │   ├── dashboard.yml
│       │   └── traefik.json
│       └── datasources/
│           └── datasource.yml
└── alertmanager/
    └── alertmanager.yml
```

## Prerequisites

- Docker and Docker Compose v2
- User in the `docker` group (no sudo needed for docker commands)
- Traefik running with the `proxy` network

```bash
# Add your user to docker group if not already
sudo usermod -aG docker $USER
# Logout and login for changes to take effect
```

## Installation

### 1. Run the install script

```bash
./install-monitoring
# Or: ./install-monitoring /srv
```

### 2. Enable Traefik metrics

Edit your Traefik configuration (`traefik.yml`):

```yaml
metrics:
  prometheus:
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
```

Restart Traefik after the change.

### 3. Configure environment variables

```bash
sudo vi /opt/monitoring/.env
```

Required variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `GRAFANA_DOMAIN` | Domain for Grafana | `grafana.example.com` |
| `PROMETHEUS_DOMAIN` | Domain for Prometheus | `prometheus.example.com` |
| `ALERTMANAGER_DOMAIN` | Domain for Alertmanager | `alertmanager.example.com` |
| `CERT_RESOLVER` | TLS resolver | `cloudflare` |
| `GRAFANA_ADMIN_USER` | Grafana admin username | `admin` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password | `changeme` |
| `PROMETHEUS_USER` | Basic auth for Prometheus | `admin:$$2y$$...` |
| `ALERTMANAGER_USER` | Basic auth for Alertmanager | `admin:$$2y$$...` |

### 4. Generate password hashes

```bash
# Using htpasswd
htpasswd -nbB admin 'yourpassword' | sed 's/\$/\$\$/g'

# Or use Traefik's gen-password script
/opt/traefik/bin/gen-password admin
```

### 5. Start the stack

```bash
cd /opt/monitoring
sudo docker compose up -d
```

## Accessing the Dashboards

| Service | URL | Auth |
|---------|-----|------|
| Grafana | `https://${GRAFANA_DOMAIN}` | Grafana login |
| Prometheus | `https://${PROMETHEUS_DOMAIN}` | Basic Auth |
| Alertmanager | `https://${ALERTMANAGER_DOMAIN}` | Basic Auth |

## Pre-configured Alerts

| Alert | Severity | Description |
|-------|----------|-------------|
| TraefikHighErrorRate | critical | >5% 5xx errors in 5 minutes |
| TraefikHighLatency | warning | P95 latency >2s |
| TraefikServiceDown | critical | Backend server not responding |
| CertificateExpiringSoon | warning | Cert expires in <7 days |
| CertificateExpired | critical | Cert has expired |
| ContainerDown | critical | Monitored container unreachable |

## Configuring Notifications

### Slack

Edit `alertmanager/alertmanager.yml`:

```yaml
receivers:
  - name: "critical"
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'
        channel: '#alerts'
        send_resolved: true
```

### Email

Edit `alertmanager/alertmanager.yml`:

```yaml
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'user'
  smtp_auth_password: 'password'

receivers:
  - name: "critical"
    email_configs:
      - to: 'admin@example.com'
        send_resolved: true
```

## Adding Custom Dashboards

1. Export dashboard JSON from Grafana
2. Place in `grafana/provisioning/dashboards/`
3. Restart Grafana: `docker compose restart grafana`

Or import directly in Grafana UI (changes persist in volume).

## Cloudflare Tunnel Integration

> **IMPORTANT**: All monitoring URLs (Grafana, Prometheus, Alertmanager) should be behind Cloudflare Zero Trust. These dashboards expose sensitive information about your infrastructure and should never be publicly accessible.

### Setup

1. Add the domains to your Cloudflare Tunnel configuration:
   - `grafana.example.com`
   - `prometheus.example.com`
   - `alertmanager.example.com`

2. Configure Access policies in Cloudflare Zero Trust dashboard:
   - Create an Access Application for each domain
   - Require authentication (email, identity provider, etc.)
   - Optionally restrict to specific users/groups

3. The services are already on the `proxy` network with Traefik

### Why Zero Trust?

| Dashboard | Exposes |
|-----------|---------|
| Grafana | Metrics, logs, infrastructure topology |
| Prometheus | All metrics, scrape targets, internal IPs |
| Alertmanager | Alert rules, notification endpoints |

Even with Basic Auth, these should be behind Zero Trust for defense in depth.

## Using Loki (Logs)

Loki automatically collects logs from all Docker containers via Promtail.

### Query logs in Grafana

1. Go to Explore → Select "Loki" datasource
2. Use LogQL queries:

```logql
# All logs from a container
{container="wordpress"}

# Filter by log level
{container="laravel"} |= "error"

# Search for specific text
{service="traefik"} |= "404"

# Regex match
{container=~"wordpress|laravel"} |~ "Exception.*"
```

### Labels available

| Label | Description |
|-------|-------------|
| `container` | Container name |
| `service` | Docker Compose service name |
| `project` | Docker Compose project name |
| `level` | Log level (if parseable) |

### Disable logging for a container

Add label to the container:

```yaml
labels:
  - "logging=false"
```

## Data Retention

Default retention settings:

| Component | Retention | Storage |
|-----------|-----------|---------|
| Prometheus | 30 days | Docker volume |
| Loki | 30 days | Docker volume |
| Grafana | Unlimited | Docker volume |
| Alertmanager | N/A | Docker volume |

To change retention, edit `docker-compose.yml` (Prometheus) or `loki/loki.yml` (Loki):

```yaml
# Prometheus
command:
  - "--storage.tsdb.retention.time=90d"

# Loki (loki.yml)
limits_config:
  retention_period: 90d
```

## Troubleshooting

### Check service status

```bash
docker compose ps
docker compose logs prometheus
docker compose logs grafana
docker compose logs loki
docker compose logs promtail
docker compose logs alertmanager
```

### Prometheus not scraping Traefik

1. Verify Traefik metrics are enabled
2. Check Traefik exposes port 8080 internally
3. Both containers must be on the same network

```bash
# Test from Prometheus container
docker exec prometheus wget -qO- http://traefik:8080/metrics | head
```

### Grafana dashboard shows "No Data"

1. Check Prometheus datasource is configured
2. Verify Prometheus is scraping targets: `https://${PROMETHEUS_DOMAIN}/targets`
3. Wait 1-2 minutes for metrics to be collected

### Loki not receiving logs

1. Check Promtail is running: `docker compose logs promtail`
2. Verify Docker socket is mounted
3. Check Loki is healthy: `docker compose logs loki`

```bash
# Test Loki API
docker exec loki wget -qO- http://localhost:3100/ready
```

## Resource Usage

Typical resource consumption:

| Service | RAM | CPU |
|---------|-----|-----|
| Prometheus | 500MB-1GB | Low |
| Loki | 100-200MB | Low |
| Promtail | 50MB | Minimal |
| Grafana | 100-200MB | Low |
| Alertmanager | 50MB | Minimal |

**Total**: ~1GB RAM for the complete stack
