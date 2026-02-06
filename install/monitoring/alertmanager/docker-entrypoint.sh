#!/bin/sh
#
# Alertmanager entrypoint with environment variable substitution
#
# Replaces ${VAR} placeholders in alertmanager.yml with environment variables
# Uses sed since envsubst is not available in the alertmanager image
#

set -e

CONFIG_TEMPLATE="/etc/alertmanager/alertmanager.yml.tmpl"
CONFIG_FILE="/etc/alertmanager/alertmanager.yml"

# Copy template to config
cp "$CONFIG_TEMPLATE" "$CONFIG_FILE"

# Replace environment variables using sed
# Each variable is replaced individually to avoid issues with special characters
sed -i "s|\${TELEGRAM_BOT_TOKEN}|${TELEGRAM_BOT_TOKEN:-}|g" "$CONFIG_FILE"
sed -i "s|\${TELEGRAM_CHAT_ID}|${TELEGRAM_CHAT_ID:-}|g" "$CONFIG_FILE"
sed -i "s|\${SLACK_WEBHOOK_URL}|${SLACK_WEBHOOK_URL:-}|g" "$CONFIG_FILE"
sed -i "s|\${SLACK_CHANNEL}|${SLACK_CHANNEL:-}|g" "$CONFIG_FILE"
sed -i "s|\${SMTP_SMARTHOST}|${SMTP_SMARTHOST:-}|g" "$CONFIG_FILE"
sed -i "s|\${SMTP_FROM}|${SMTP_FROM:-}|g" "$CONFIG_FILE"
sed -i "s|\${SMTP_AUTH_USERNAME}|${SMTP_AUTH_USERNAME:-}|g" "$CONFIG_FILE"
sed -i "s|\${SMTP_AUTH_PASSWORD}|${SMTP_AUTH_PASSWORD:-}|g" "$CONFIG_FILE"
sed -i "s|\${ALERT_EMAIL_TO}|${ALERT_EMAIL_TO:-}|g" "$CONFIG_FILE"

# Start alertmanager with all passed arguments
exec /bin/alertmanager "$@"
