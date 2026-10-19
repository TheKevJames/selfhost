# shellcheck shell=bash
# Discord alerting shared by the bin/ scripts, via the webhook dolce also uses.
# Source this file; both functions return non-zero on failure and leave the
# policy (ignore vs. fail the run) to the caller.

ALERT_ENV_FILE="${DOLCE_ENV_FILE:-$(dirname -- "${BASH_SOURCE[0]}")/../../secrets/dolce.env}"

alert_load_webhook() {
    if [[ ! -r "$ALERT_ENV_FILE" ]]; then
        printf 'alert: cannot read env file: %s\n' "$ALERT_ENV_FILE" >&2
        return 1
    fi
    # Subshell keeps the rest of the env file out of the caller's environment.
    # shellcheck source=/dev/null
    DISCORD_WEBHOOK="$(. "$ALERT_ENV_FILE"; printf '%s' "${DISCORD_WEBHOOK:-}")"
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        printf 'alert: DISCORD_WEBHOOK not set in %s\n' "$ALERT_ENV_FILE" >&2
        return 1
    fi
}

alert() {
    [[ -n "${DISCORD_WEBHOOK:-}" ]] || alert_load_webhook || return 1
    # Discord rejects content over 2000 characters.
    local msg=${1:0:1900}
    msg=${msg//\\/\\\\}
    msg=${msg//\"/\\\"}
    msg=${msg//$'\r'/}
    msg=${msg//$'\n'/\\n}
    msg=${msg//$'\t'/\\t}
    curl -fsS -H 'Content-Type: application/json' -X POST \
        -d "{\"content\":\"$msg\"}" "$DISCORD_WEBHOOK" >/dev/null
}
