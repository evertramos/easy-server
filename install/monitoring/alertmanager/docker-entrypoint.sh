#!/bin/sh
#
# Alertmanager entrypoint with envsubst support
#
# Replaces ${VAR} placeholders in alertmanager.yml with environment variables
#

set -e

CONFIG_TEMPLATE="/etc/alertmanager/alertmanager.yml.tmpl"
CONFIG_FILE="/etc/alertmanager/alertmanager.yml"

# Run envsubst to replace environment variables
# Only substitute our specific variables (preserve Alertmanager's {{ }} templates)
envsubst '${TELEGRAM_BOT_TOKEN} ${TELEGRAM_CHAT_ID} ${SLACK_WEBHOOK_URL} ${SLACK_CHANNEL} ${SMTP_SMARTHOST} ${SMTP_FROM} ${SMTP_AUTH_USERNAME} ${SMTP_AUTH_PASSWORD} ${ALERT_EMAIL_TO}' \
    < "$CONFIG_TEMPLATE" \
    > "$CONFIG_FILE"

# Start alertmanager with all passed arguments
exec /bin/alertmanager "$@"
