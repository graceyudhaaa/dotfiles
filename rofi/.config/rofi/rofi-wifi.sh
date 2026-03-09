#!/bin/bash

# ─── Debug / Logging ────────────────────────────────────────────────
# Set DEBUG=1 to enable verbose terminal logging
# Usage: DEBUG=1 ./rofi-wifi.sh
# Or:    ./rofi-wifi.sh --debug
DEBUG="${DEBUG:-0}"
ROFI_THEME="$HOME/.config/rofi/themes/tokyonight.rasi"
LOG_FILE="/tmp/rofi-wifi.log"
DEBUG_LOG="/tmp/rofi-wifi-debug.log"
NOTIFY_ICON="network-wireless"

# Enable debug via --debug flag
for arg in "$@"; do
    case "$arg" in
        --debug|-d) DEBUG=1 ;;
        --help|-h)
            echo "Usage: $0 [--debug|-d] [--help|-h]"
            echo "  --debug, -d   Enable verbose debug logging to terminal and $DEBUG_LOG"
            exit 0
            ;;
    esac
done

# ─── Logging Functions ──────────────────────────────────────────────

_log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local caller="${FUNCNAME[2]:-main}"
    local line="${BASH_LINENO[1]:-0}"
    local msg="[$timestamp] [$level] ($caller:$line) $*"

    if [ "$DEBUG" = "1" ]; then
        case "$level" in
            ERROR) echo -e "\033[1;31m$msg\033[0m" ;;
            WARN)  echo -e "\033[1;33m$msg\033[0m" ;;
            INFO)  echo -e "\033[1;34m$msg\033[0m" ;;
            DEBUG) echo -e "\033[0;37m$msg\033[0m" ;;
            CMD)   echo -e "\033[1;36m$msg\033[0m" ;;
            OK)    echo -e "\033[1;32m$msg\033[0m" ;;
        esac
        echo "$msg" >> "$DEBUG_LOG"
    fi
}

log_debug() { _log DEBUG "$@"; }
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }
log_cmd()   { _log CMD   "$@"; }
log_ok()    { _log OK    "$@"; }

run_cmd() {
    local desc="$1"
    shift
    log_cmd "EXEC: $* ($desc)"

    local output exit_code
    output=$("$@" 2>&1)
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_ok "EXIT=$exit_code: $desc"
    else
        log_error "EXIT=$exit_code: $desc"
    fi

    if [ -n "$output" ] && [ "$DEBUG" = "1" ]; then
        while IFS= read -r line; do
            log_debug "  | $line"
        done <<< "$output"
    fi

    echo "$output"
    return $exit_code
}

# Initialize debug session (non-blocking — fire and forget)
if [ "$DEBUG" = "1" ]; then
    {
        echo ""
        echo "════════════════════════════════════════════════════════════"
    } >> "$DEBUG_LOG"
    _log INFO "═══ rofi-wifi.sh started (PID: $$) ═══"
    _log INFO "Date: $(date)"
    _log INFO "User: $(whoami)"
    _log INFO "Shell: $SHELL ($BASH_VERSION)"
    _log INFO "Theme: $ROFI_THEME"
    _log INFO "Debug log: $DEBUG_LOG"

    # Fire and forget — don't wait
    {
        nmcli --version 2>/dev/null | while read -r line; do _log INFO "nmcli version: $line"; done
        rofi -version 2>/dev/null | head -1 | while read -r line; do _log INFO "rofi version: $line"; done
        systemctl is-active NetworkManager 2>/dev/null | while read -r line; do _log INFO "NetworkManager status: $line"; done
    } &

    for dep in nmcli rofi notify-send; do
        if command -v "$dep" >/dev/null 2>&1; then
            _log OK "Dependency found: $dep"
        else
            _log ERROR "Dependency MISSING: $dep"
        fi
    done
    # Removed: wait
fi

trap 'log_info "Cleaning up temp files"; rm -f "$LOG_FILE"; log_info "═══ rofi-wifi.sh exited (code: $?) ═══"' EXIT

# ─── Helper Functions ────────────────────────────────────────────────

notify() {
    log_info "NOTIFY: $1"
    notify-send -i "$NOTIFY_ICON" "WiFi" "$1" &
}

rofi_menu() {
    log_debug "rofi_menu called with args: $*"
    local result
    result=$(rofi -dmenu -theme "$ROFI_THEME" "$@")
    local exit_code=$?
    if [ $exit_code -ne 0 ] || [ -z "$result" ]; then
        log_debug "rofi_menu: user cancelled or empty selection (exit=$exit_code)"
    else
        log_debug "rofi_menu: selected='$result'"
    fi
    echo "$result"
    return $exit_code
}

rofi_msg() {
    log_debug "rofi_msg: $1"
    rofi -theme "$ROFI_THEME" -e "$1"
}

get_current_ssid() {
    local ssid
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
    log_debug "Current SSID: '${ssid:-<none>}'"
    echo "$ssid"
}

get_wifi_state() {
    local state
    state=$(nmcli radio wifi)
    log_debug "WiFi radio state: $state"
    echo "$state"
}

_CACHED_WIFI_DEVICE=""
get_wifi_device() {
    if [ -z "$_CACHED_WIFI_DEVICE" ]; then
        _CACHED_WIFI_DEVICE=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
    fi
    log_debug "WiFi device: '${_CACHED_WIFI_DEVICE:-<none>}'"
    echo "$_CACHED_WIFI_DEVICE"
}
signal_icon() {
    local signal=$1
    if [ "$signal" -ge 80 ]; then echo "󰤨"
    elif [ "$signal" -ge 60 ]; then echo "󰤥"
    elif [ "$signal" -ge 40 ]; then echo "󰤢"
    elif [ "$signal" -ge 20 ]; then echo "󰤟"
    else echo "󰤯"
    fi
}

security_icon() {
    local sec="$1"
    if [ "$sec" = "open" ] || [ "$sec" = "--" ] || [ -z "$sec" ]; then
        echo "󰌾"
    else
        echo "󰌷"
    fi
}

get_band() {
    local freq="$1"
    if [ -z "$freq" ]; then echo ""
    elif [ "$freq" -ge 5000 ] 2>/dev/null; then echo "5 GHz"
    elif [ "$freq" -ge 2400 ] 2>/dev/null; then echo "2.4 GHz"
    else echo ""
    fi
}

# Detect if a network uses WPA Enterprise (802.1X)
is_enterprise() {
    local security="$1"
    case "$security" in
        *"802.1X"*|*"WPA3-Enterprise"*|*"WPA2-Enterprise"*|*"enterprise"*|*"EAP"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wifi_list() {
    log_info "Building WiFi list from cache..."

    # Fire off rescan in background — don't wait at all
    # nmcli dev wifi rescan 2>/dev/null &

    # Pre-fetch saved networks once
    local saved_networks
    saved_networks=$(nmcli -t -f NAME connection show 2>/dev/null)

    # Use awk to do ALL formatting in a single process instead of
    # spawning subshells per line (signal_icon, security_icon, get_band, is_enterprise)
    nmcli -t -f SSID,SIGNAL,SECURITY,FREQ dev wifi 2>/dev/null \
        | grep -v '^:' \
        | sort -t: -k2,2 -rn \
        | awk -F: -v saved="$saved_networks" '
        BEGIN {
            # Build saved network lookup
            n = split(saved, arr, "\n")
            for (i = 1; i <= n; i++) saved_map[arr[i]] = 1
        }
        !seen[$1]++ && $1 != "" {
            ssid = $1
            signal = $2 + 0
            security = $3
            freq = $4 + 0

            # signal_icon
            if (signal >= 80) sig_icon = "󰤨"
            else if (signal >= 60) sig_icon = "󰤥"
            else if (signal >= 40) sig_icon = "󰤢"
            else if (signal >= 20) sig_icon = "󰤟"
            else sig_icon = "󰤯"

            # security_icon
            if (security == "" || security == "--")
                lock = "󰌾"
            else
                lock = "󰌷"

            # sec label
            if (security == "" || security == "--")
                sec = "open"
            else
                sec = security

            # get_band
            if (freq >= 5000) band = "5 GHz"
            else if (freq >= 2400) band = "2.4 GHz"
            else band = ""

            # is_enterprise
            ent_tag = ""
            if (security ~ /802\.1X|WPA[23]-Enterprise|enterprise|EAP/)
                ent_tag = " 󰈸"

            # saved check
            saved_tag = ""
            if (ssid in saved_map) saved_tag = " 󰆓"

            printf "%s %s  %-28s  %3d%%  %s  %s%s%s\n", sig_icon, lock, ssid, signal, sec, band, ent_tag, saved_tag
        }'
}

extract_ssid() {
    local extracted
    extracted=$(echo "$1" | sed 's/^[^ ]* [^ ]*  //' | sed 's/\s\+[0-9]\+%\s\+.*$//' | sed 's/\s*$//')
    log_debug "extract_ssid: input='$1' -> output='$extracted'"
    echo "$extracted"
}

# ─── 802.1X / WPA Enterprise Connection ─────────────────────────────
# Mimics GNOME's WiFi > Security tab for Enterprise networks

connect_enterprise() {
    local ssid="$1"
    local wifi_dev
    wifi_dev=$(get_wifi_device)

    log_info "Starting WPA Enterprise connection wizard for '$ssid'"

    # ── Step 1: EAP Method ──
    local eap_method
    eap_method=$(printf "PEAP\nTTLS\nTLS\nPWD\nFAST\nLEAP" \
        | rofi_menu -p "󰒍 EAP Method" -mesg "Select authentication method for $ssid")
    [ -z "$eap_method" ] && { log_debug "Enterprise: EAP method cancelled"; return 1; }
    log_info "Enterprise EAP method: $eap_method"

    # ── Step 2: Phase 2 / Inner authentication (for PEAP, TTLS, FAST) ──
    local phase2=""
    case "$eap_method" in
        PEAP)
            phase2=$(printf "MSCHAPv2\nMD5\nGTC" \
                | rofi_menu -p "󰒍 Inner Auth" -mesg "PEAP inner authentication")
            [ -z "$phase2" ] && { log_debug "Enterprise: Phase2 cancelled"; return 1; }
            log_info "Enterprise Phase2 (PEAP): $phase2"
            ;;
        TTLS)
            phase2=$(printf "PAP\nMSCHAPv2\nMSCHAP\nCHAP\nMD5\nGTC" \
                | rofi_menu -p "󰒍 Inner Auth" -mesg "TTLS inner authentication")
            [ -z "$phase2" ] && { log_debug "Enterprise: Phase2 cancelled"; return 1; }
            log_info "Enterprise Phase2 (TTLS): $phase2"
            ;;
        FAST)
            phase2=$(printf "MSCHAPv2\nGTC" \
                | rofi_menu -p "󰒍 Inner Auth" -mesg "FAST inner authentication")
            [ -z "$phase2" ] && { log_debug "Enterprise: Phase2 cancelled"; return 1; }
            log_info "Enterprise Phase2 (FAST): $phase2"
            ;;
    esac

    # ── Step 3: CA Certificate (optional) ──
    local ca_cert=""
    local ca_choice
    ca_choice=$(printf "No CA certificate (insecure)\nSelect CA certificate file\nUse system certificates" \
        | rofi_menu -p "󰄤 CA Certificate" -mesg "Certificate Authority validation\n(Recommended for security)")

    case "$ca_choice" in
        *"Select CA"*)
            ca_cert=$(rofi_menu -p "CA cert path" <<< "/etc/ssl/certs/")
            if [ -n "$ca_cert" ] && [ ! -f "$ca_cert" ]; then
                log_warn "CA cert file not found: $ca_cert"
                rofi_msg "File not found: $ca_cert\nContinuing without CA certificate."
                ca_cert=""
            fi
            log_info "Enterprise CA cert: '${ca_cert:-none}'"
            ;;
        *"system certificates"*)
            ca_cert="/etc/ssl/certs/ca-certificates.crt"
            if [ ! -f "$ca_cert" ]; then
                # Try alternative paths
                for alt in /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/ca-bundle.pem; do
                    if [ -f "$alt" ]; then
                        ca_cert="$alt"
                        break
                    fi
                done
            fi
            log_info "Enterprise CA cert (system): '$ca_cert'"
            ;;
        *)
            ca_cert=""
            log_info "Enterprise: no CA certificate"
            ;;
    esac

    # ── Step 4: Anonymous identity (optional, for PEAP/TTLS) ──
    local anon_identity=""
    if [ "$eap_method" = "PEAP" ] || [ "$eap_method" = "TTLS" ] || [ "$eap_method" = "FAST" ]; then
        anon_identity=$(rofi_menu -p "Anonymous identity (optional)" \
            -mesg "Outer identity sent before the TLS tunnel.\nLeave blank to skip (e.g. anonymous@example.com)")
        log_info "Enterprise anonymous identity: '${anon_identity:-<empty>}'"
    fi

    # ── Step 5: Identity (username) ──
    local identity
    identity=$(rofi_menu -p "󰀄 Username / Identity" \
        -mesg "Your username for $ssid\n(e.g. user@university.edu)")
    [ -z "$identity" ] && { log_debug "Enterprise: identity cancelled"; return 1; }
    log_info "Enterprise identity: '$identity'"

    # ── Step 6: Domain (optional, for server cert validation) ──
    local domain=""
    domain=$(rofi_menu -p "Domain (optional)" \
        -mesg "Expected server certificate domain\n(e.g. radius.university.edu)\nLeave blank to skip")
    log_info "Enterprise domain: '${domain:-<empty>}'"

    # ── Step 7: Password ──
    local password
    if [ "$eap_method" = "TLS" ]; then
        # TLS uses client certificates instead of password
        log_info "EAP-TLS: prompting for client certificate paths"

        local client_cert
        client_cert=$(rofi_menu -p "Client certificate path" \
            -mesg "Path to your client certificate (.pem/.p12)")
        [ -z "$client_cert" ] && { log_debug "Enterprise TLS: client cert cancelled"; return 1; }

        local private_key
        private_key=$(rofi_menu -p "Private key path" \
            -mesg "Path to your private key file")
        [ -z "$private_key" ] && { log_debug "Enterprise TLS: private key cancelled"; return 1; }

        local private_key_password
        private_key_password=$(rofi_menu -password -p "Private key password (if any)" \
            -mesg "Leave blank if key is not encrypted")

        log_info "Enterprise TLS: cert='$client_cert' key='$private_key'"
    else
        password=$(rofi_menu -password -p "󰌷 Password for $identity" \
            -mesg "Enter your password for $ssid")
        [ -z "$password" ] && { log_debug "Enterprise: password cancelled"; return 1; }
        log_info "Enterprise: password entered (hidden)"
    fi

    # ── Step 8: Preview & Confirm ──
    local preview=""
    preview+="Network:         $ssid\n"
    preview+="EAP Method:      $eap_method\n"
    [ -n "$phase2" ] && preview+="Inner Auth:      $phase2\n"
    [ -n "$ca_cert" ] && preview+="CA Certificate:  $ca_cert\n"
    [ -n "$anon_identity" ] && preview+="Anon Identity:   $anon_identity\n"
    preview+="Identity:        $identity\n"
    [ -n "$domain" ] && preview+="Domain:          $domain\n"
    if [ "$eap_method" = "TLS" ]; then
        preview+="Client Cert:     $client_cert\n"
        preview+="Private Key:     $private_key\n"
    fi

    local confirm
    confirm=$(printf "  Connect\n  Edit\n  Cancel" \
        | rofi_menu -p "Confirm" -mesg "$(echo -e "═══ Enterprise WiFi Setup ═══\n$preview")")

    case "$confirm" in
        *"Connect")
            log_info "Proceeding with Enterprise connection"
            ;;
        *"Edit")
            log_info "User chose to re-edit, restarting wizard"
            connect_enterprise "$ssid"
            return $?
            ;;
        *)
            log_info "Enterprise connection cancelled"
            return 1
            ;;
    esac

    # ── Step 9: Build and execute nmcli command ──
    notify "Connecting to $ssid (Enterprise)..."
    log_info "Building nmcli Enterprise connection command"

    # Delete any existing connection profile for this SSID first
    if nmcli -t -f NAME connection show | grep -qx "$ssid"; then
        log_info "Removing existing profile for '$ssid'"
        nmcli connection delete id "$ssid" >/dev/null 2>&1
    fi

    # Base connection command
    local -a cmd=(nmcli connection add type wifi ifname "$wifi_dev" con-name "$ssid" ssid "$ssid")

    # WiFi security settings
    cmd+=(wifi-sec.key-mgmt wpa-eap)

    # 802.1X EAP settings
    cmd+=(802-1x.eap "$(echo "$eap_method" | tr '[:upper:]' '[:lower:]')")
    cmd+=(802-1x.identity "$identity")

    # Phase 2
    if [ -n "$phase2" ]; then
        local phase2_val
        case "$eap_method" in
            PEAP)
                phase2_val="auth=$(echo "$phase2" | tr '[:upper:]' '[:lower:]')"
                ;;
            TTLS)
                phase2_val="auth=$(echo "$phase2" | tr '[:upper:]' '[:lower:]')"
                ;;
            FAST)
                phase2_val="auth=$(echo "$phase2" | tr '[:upper:]' '[:lower:]')"
                ;;
        esac
        cmd+=(802-1x.phase2-auth "$(echo "$phase2" | tr '[:upper:]' '[:lower:]')")
    fi

    # CA Certificate
    if [ -n "$ca_cert" ] && [ -f "$ca_cert" ]; then
        cmd+=(802-1x.ca-cert "$ca_cert")
    fi

    # Anonymous identity
    if [ -n "$anon_identity" ]; then
        cmd+=(802-1x.anonymous-identity "$anon_identity")
    fi

    # Domain constraint
    if [ -n "$domain" ]; then
        cmd+=(802-1x.domain-suffix-match "$domain")
    fi

    # Auth-specific: TLS uses certs, others use password
    if [ "$eap_method" = "TLS" ]; then
        cmd+=(802-1x.client-cert "$client_cert")
        cmd+=(802-1x.private-key "$private_key")
        if [ -n "$private_key_password" ]; then
            cmd+=(802-1x.private-key-password "$private_key_password")
        fi
    else
        cmd+=(802-1x.password "$password")
    fi

    # Log the command (mask sensitive fields)
    local cmd_log="${cmd[*]}"
    cmd_log=$(echo "$cmd_log" | sed 's/802-1x.password [^ ]*/802-1x.password ******/g')
    cmd_log=$(echo "$cmd_log" | sed 's/802-1x.private-key-password [^ ]*/802-1x.private-key-password ******/g')
    log_cmd "Enterprise connect: $cmd_log"

    # Create the connection profile
    "${cmd[@]}" >"$LOG_FILE" 2>&1
    local add_exit=$?

    if [ $add_exit -ne 0 ]; then
        local err
        err=$(cat "$LOG_FILE")
        log_error "Failed to create Enterprise profile: $err"
        rofi_msg "Failed to create connection:\n$err"
        return 1
    fi
    log_ok "Enterprise connection profile created"

    # Activate the connection
    nmcli connection up id "$ssid" >"$LOG_FILE" 2>&1
    local up_exit=$?

    if [ $up_exit -eq 0 ] && grep -q "successfully activated" "$LOG_FILE"; then
        log_ok "Connected to Enterprise network '$ssid'"
        notify "Connected to $ssid (Enterprise)"
        return 0
    else
        local err
        err=$(cat "$LOG_FILE")
        log_error "Enterprise activation failed: $err"

        local retry
        retry=$(printf "  Retry with different settings\n  View error details\n  Delete profile & cancel\n  Cancel" \
            | rofi_menu -p "Connection Failed" -mesg "Could not connect to $ssid")

        case "$retry" in
            *"Retry"*)
                log_info "Retrying Enterprise connection"
                nmcli connection delete id "$ssid" >/dev/null 2>&1
                connect_enterprise "$ssid"
                return $?
                ;;
            *"View error"*)
                rofi_msg "$err"
                nmcli connection delete id "$ssid" >/dev/null 2>&1
                return 1
                ;;
            *"Delete"*)
                nmcli connection delete id "$ssid" >/dev/null 2>&1
                log_info "Deleted failed Enterprise profile for '$ssid'"
                return 1
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# ─── Edit Enterprise Connection ─────────────────────────────────────
# Edit 802.1X settings on an existing saved connection (like GNOME's Security tab)

edit_enterprise_settings() {
    local ssid="$1"
    log_info "Editing Enterprise settings for '$ssid'"

    # Read current settings
    local cur_eap cur_phase2 cur_identity cur_anon_id cur_ca cur_domain
    cur_eap=$(nmcli -t -f 802-1x.eap connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    cur_phase2=$(nmcli -t -f 802-1x.phase2-auth connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    cur_identity=$(nmcli -t -f 802-1x.identity connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    cur_anon_id=$(nmcli -t -f 802-1x.anonymous-identity connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    cur_ca=$(nmcli -t -f 802-1x.ca-cert connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    cur_domain=$(nmcli -t -f 802-1x.domain-suffix-match connection show id "$ssid" 2>/dev/null | cut -d: -f2)

    log_debug "Current Enterprise settings: eap=$cur_eap phase2=$cur_phase2 id=$cur_identity anon=$cur_anon_id ca=$cur_ca domain=$cur_domain"

    local info=""
    info+="Current 802.1X Settings for $ssid\n"
    info+="══════════════════════════════════\n"
    info+="EAP Method:       ${cur_eap:-not set}\n"
    info+="Inner Auth:       ${cur_phase2:-not set}\n"
    info+="Identity:         ${cur_identity:-not set}\n"
    info+="Anon Identity:    ${cur_anon_id:-not set}\n"
    info+="CA Certificate:   ${cur_ca:-none}\n"
    info+="Domain:           ${cur_domain:-not set}"

    local action
    action=$(printf "  Change Identity\n  Change Password\n  Change EAP Method\n  Change Inner Auth\n  Change CA Certificate\n  Change Anonymous Identity\n  Change Domain\n  Reconnect\n  Back" \
        | rofi_menu -p "󰒍 802.1X Settings" -mesg "$(echo -e "$info")")

    log_info "Enterprise edit action: '$action'"

    case "$action" in
        *"Change Identity"*)
            local new_id
            new_id=$(rofi_menu -p "New identity" <<< "$cur_identity")
            [ -z "$new_id" ] && return
            run_cmd "Change identity" nmcli connection modify id "$ssid" 802-1x.identity "$new_id"
            notify "Identity updated for $ssid"
            ;;
        *"Change Password"*)
            local new_pass
            new_pass=$(rofi_menu -password -p "New password")
            [ -z "$new_pass" ] && return
            run_cmd "Change password" nmcli connection modify id "$ssid" 802-1x.password "$new_pass"
            notify "Password updated for $ssid"
            ;;
        *"Change EAP Method"*)
            local new_eap
            new_eap=$(printf "peap\nttls\ntls\npwd\nfast\nleap" | rofi_menu -p "EAP Method")
            [ -z "$new_eap" ] && return
            run_cmd "Change EAP" nmcli connection modify id "$ssid" 802-1x.eap "$new_eap"
            notify "EAP method changed to $new_eap"
            ;;
        *"Change Inner Auth"*)
            local new_phase2
            new_phase2=$(printf "mschapv2\nmd5\ngtc\npap\nmschap\nchap" | rofi_menu -p "Inner Auth")
            [ -z "$new_phase2" ] && return
            run_cmd "Change phase2" nmcli connection modify id "$ssid" 802-1x.phase2-auth "$new_phase2"
            notify "Inner auth changed to $new_phase2"
            ;;
        *"Change CA Certificate"*)
            local new_ca
            new_ca=$(printf "None (disable validation)\nSystem certificates\nCustom path..." \
                | rofi_menu -p "CA Certificate")
            case "$new_ca" in
                *"None"*)
                    run_cmd "Remove CA cert" nmcli connection modify id "$ssid" 802-1x.ca-cert ""
                    ;;
                *"System"*)
                    local sys_ca="/etc/ssl/certs/ca-certificates.crt"
                    for alt in /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/ca-bundle.pem; do
                        [ -f "$alt" ] && sys_ca="$alt" && break
                    done
                    run_cmd "Set system CA" nmcli connection modify id "$ssid" 802-1x.ca-cert "$sys_ca"
                    ;;
                *"Custom"*)
                    local ca_path
                    ca_path=$(rofi_menu -p "CA cert path")
                    [ -n "$ca_path" ] && run_cmd "Set custom CA" nmcli connection modify id "$ssid" 802-1x.ca-cert "$ca_path"
                    ;;
            esac
            notify "CA certificate updated"
            ;;
        *"Change Anonymous Identity"*)
            local new_anon
            new_anon=$(rofi_menu -p "Anonymous identity" <<< "$cur_anon_id")
            run_cmd "Change anon identity" nmcli connection modify id "$ssid" 802-1x.anonymous-identity "${new_anon:-}"
            notify "Anonymous identity updated"
            ;;
        *"Change Domain"*)
            local new_domain
            new_domain=$(rofi_menu -p "Domain suffix" <<< "$cur_domain")
            run_cmd "Change domain" nmcli connection modify id "$ssid" 802-1x.domain-suffix-match "${new_domain:-}"
            notify "Domain constraint updated"
            ;;
        *"Reconnect"*)
            log_info "Reconnecting to '$ssid' with updated settings"
            nmcli connection down id "$ssid" >/dev/null 2>&1
            nmcli connection up id "$ssid" >"$LOG_FILE" 2>&1
            if grep -q "successfully activated" "$LOG_FILE"; then
                notify "Reconnected to $ssid"
            else
                rofi_msg "Reconnection failed:\n$(tail -1 "$LOG_FILE")"
            fi
            ;;
    esac
}

# ─── Connection Details ─────────────────────────────────────────────


show_connection_details() {
    local ssid="$1"
    local wifi_dev
    wifi_dev=$(get_wifi_device)

    log_info "Showing connection details for '$ssid' on device '$wifi_dev'"

    # Single nmcli call for device info — parse all fields at once
    local dev_info
    dev_info=$(nmcli -t dev show "$wifi_dev" 2>/dev/null)

    local ip gateway dns ipv6 mac speed
    ip=$(echo "$dev_info" | grep '^IP4.ADDRESS' | head -1 | cut -d: -f2-)
    gateway=$(echo "$dev_info" | grep '^IP4.GATEWAY' | head -1 | cut -d: -f2-)
    dns=$(echo "$dev_info" | grep '^IP4.DNS' | head -1 | cut -d: -f2-)
    ipv6=$(echo "$dev_info" | grep '^IP6.ADDRESS' | head -1 | cut -d: -f2-)
    mac=$(echo "$dev_info" | grep '^GENERAL.HWADDR' | head -1 | cut -d: -f2-)
    speed=$(echo "$dev_info" | grep '^WIFI.BITRATE' | head -1 | cut -d: -f2-)

    # Single nmcli call for active wifi stats
    local wifi_info
    wifi_info=$(nmcli -t -f active,signal,freq,security dev wifi 2>/dev/null | grep '^yes')

    local signal freq security
    signal=$(echo "$wifi_info" | cut -d: -f2)
    freq=$(echo "$wifi_info" | cut -d: -f3)
    security=$(echo "$wifi_info" | cut -d: -f4)

    log_debug "Details: ip=$ip gw=$gateway dns=$dns mac=$mac speed=$speed signal=$signal freq=$freq sec=$security"

    local band
    band=$(get_band "$freq")
    local sig_icon
    sig_icon=$(signal_icon "${signal:-0}")

    # Single nmcli call for connection settings (batch eap, identity, autoconnect, metered)
    local conn_info
    conn_info=$(nmcli -t -f 802-1x.eap,802-1x.identity,connection.autoconnect,connection.metered \
        connection show id "$ssid" 2>/dev/null)

    local conn_eap conn_identity autoconnect_val metered_val
    conn_eap=$(echo "$conn_info" | grep '^802-1x.eap' | cut -d: -f2)
    conn_identity=$(echo "$conn_info" | grep '^802-1x.identity' | cut -d: -f2)
    autoconnect_val=$(echo "$conn_info" | grep '^connection.autoconnect' | cut -d: -f2)
    metered_val=$(echo "$conn_info" | grep '^connection.metered' | cut -d: -f2)

    local details=""
    details+="╔══════════════════════════════════════╗\n"
    details+="║  Connection Details                  ║\n"
    details+="╠══════════════════════════════════════╣\n"
    details+="║  SSID:       $ssid\n"
    details+="║  Signal:     $sig_icon ${signal:-?}%\n"
    details+="║  Security:   ${security:-unknown}\n"
    if [ -n "$conn_eap" ]; then
        details+="║  Auth:       802.1X ($conn_eap)\n"
        details+="║  Identity:   ${conn_identity:-unknown}\n"
    fi
    details+="║  Band:       ${band:-unknown} (${freq:-?} MHz)\n"
    details+="║  Speed:      ${speed:-unknown}\n"
    details+="╠══════════════════════════════════════╣\n"
    details+="║  IPv4:       ${ip:-not assigned}\n"
    details+="║  Gateway:    ${gateway:-not assigned}\n"
    details+="║  DNS:        ${dns:-not assigned}\n"
    details+="║  IPv6:       ${ipv6:-not assigned}\n"
    details+="║  MAC:        ${mac:-unknown}\n"
    details+="╚══════════════════════════════════════╝"

    # Build menu — include 802.1X option if it's an enterprise connection
    local menu_items="  Back\n  Forget Network\n  Change DNS\n  Auto-connect: $autoconnect_val\n  Metered: $metered_val\n  Copy IP Address\n  Disconnect"
    if [ -n "$conn_eap" ]; then
        menu_items="  Back\n  802.1X Settings\n  Forget Network\n  Change DNS\n  Auto-connect: $autoconnect_val\n  Metered: $metered_val\n  Copy IP Address\n  Disconnect"
    fi

    local action
    action=$(printf "$menu_items" \
        | rofi_menu -p "  $ssid" -mesg "$(echo -e "$details")")

    log_info "Connection details action: '$action'"

    case "$action" in
        *"Back")
            return 0
            ;;
        *"802.1X Settings"*)
            edit_enterprise_settings "$ssid"
            ;;
        *"Forget Network")
            confirm=$(printf "Yes, forget\nCancel" | rofi_menu -p "Forget $ssid?")
            if [ "$confirm" = "Yes, forget" ]; then
                log_info "Forgetting network '$ssid'"
                run_cmd "Forget $ssid" nmcli connection delete id "$ssid"
                notify "Forgot network: $ssid"
            fi
            ;;
        *"Change DNS")
            change_dns "$ssid"
            ;;
        *"Auto-connect"*)
            toggle_autoconnect "$ssid"
            ;;
        *"Metered"*)
            toggle_metered "$ssid"
            ;;
        *"Copy IP Address")
            if [ -n "$ip" ]; then
                echo -n "$ip" | wl-copy
                log_ok "IP copied to clipboard: $ip"
                notify "IP copied: $ip"
            else
                log_warn "No IP to copy"
            fi
            ;;
        *"Disconnect")
            log_info "Disconnecting from '$ssid'"
            nmcli connection down id "$ssid" 2>/dev/null || nmcli dev disconnect "$wifi_dev" 2>/dev/null
            notify "Disconnected from $ssid"
            ;;
    esac
}

# ─── DNS Settings ───────────────────────────────────────────────────

change_dns() {
    local ssid="$1"
    local current_dns
    current_dns=$(nmcli -t -f ipv4.dns connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    log_info "Changing DNS for '$ssid' (current: '${current_dns:-automatic}')"

    local choice
    choice=$(printf "  Automatic (DHCP)\n  Cloudflare (1.1.1.1)\n  Google (8.8.8.8)\n  Quad9 (9.9.9.9)\n  AdGuard (94.140.14.14)\n  Custom...\n  Back" \
        | rofi_menu -p "DNS for $ssid" -mesg "Current DNS: ${current_dns:-automatic}")

    log_info "DNS choice: '$choice'"

    case "$choice" in
        *"Automatic"*)
            run_cmd "DNS auto" nmcli connection modify id "$ssid" ipv4.dns "" ipv4.ignore-auto-dns no
            ;;
        *"Cloudflare"*)
            run_cmd "DNS Cloudflare" nmcli connection modify id "$ssid" ipv4.dns "1.1.1.1 1.0.0.1" ipv4.ignore-auto-dns yes
            ;;
        *"Google"*)
            run_cmd "DNS Google" nmcli connection modify id "$ssid" ipv4.dns "8.8.8.8 8.8.4.4" ipv4.ignore-auto-dns yes
            ;;
        *"Quad9"*)
            run_cmd "DNS Quad9" nmcli connection modify id "$ssid" ipv4.dns "9.9.9.9 149.112.112.112" ipv4.ignore-auto-dns yes
            ;;
        *"AdGuard"*)
            run_cmd "DNS AdGuard" nmcli connection modify id "$ssid" ipv4.dns "94.140.14.14 94.140.15.15" ipv4.ignore-auto-dns yes
            ;;
        *"Custom"*)
            custom_dns=$(rofi_menu -p "Enter DNS (space-separated)")
            [ -z "$custom_dns" ] && return
            run_cmd "DNS custom" nmcli connection modify id "$ssid" ipv4.dns "$custom_dns" ipv4.ignore-auto-dns yes
            ;;
        *)
            log_debug "DNS change cancelled"
            return
            ;;
    esac

    log_info "Reapplying connection '$ssid' for DNS change"
    run_cmd "Reapply connection" nmcli connection up id "$ssid"
    notify "DNS updated for $ssid"
}

# ─── Toggle Auto-connect ────────────────────────────────────────────

toggle_autoconnect() {
    local ssid="$1"
    local current
    current=$(nmcli -t -f connection.autoconnect connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    log_info "Toggling autoconnect for '$ssid' (current: $current)"

    if [ "$current" = "yes" ]; then
        run_cmd "Disable autoconnect" nmcli connection modify id "$ssid" connection.autoconnect no
        notify "Auto-connect disabled for $ssid"
    else
        run_cmd "Enable autoconnect" nmcli connection modify id "$ssid" connection.autoconnect yes
        notify "Auto-connect enabled for $ssid"
    fi
}

# ─── Toggle Metered Network ─────────────────────────────────────────

toggle_metered() {
    local ssid="$1"
    local current
    current=$(nmcli -t -f connection.metered connection show id "$ssid" 2>/dev/null | cut -d: -f2)
    log_info "Toggling metered for '$ssid' (current: $current)"

    if [ "$current" = "yes" ]; then
        run_cmd "Disable metered" nmcli connection modify id "$ssid" connection.metered no
        notify "Metered disabled for $ssid"
    else
        run_cmd "Enable metered" nmcli connection modify id "$ssid" connection.metered yes
        notify "Metered enabled for $ssid (data usage tracking)"
    fi
}

# ─── Saved Networks Manager ─────────────────────────────────────────

manage_saved_networks() {
    log_info "Opening saved networks manager"
    local saved_list
    saved_list=$(nmcli -t -f NAME,TYPE connection show | awk -F: '$2=="802-11-wireless" {print $1}')

    if [ -z "$saved_list" ]; then
        log_warn "No saved WiFi networks found"
        rofi_msg "No saved WiFi networks found."
        return
    fi

    local count
    count=$(echo "$saved_list" | wc -l)
    log_info "Found $count saved WiFi networks"

    local menu=""
    local names=()
    readarray -t names <<< "$saved_list"
    
    for name in "${names[@]}"; do
        local autoconnect
        autoconnect=$(nmcli -t -f connection.autoconnect connection show id "$name" 2>/dev/null | cut -d: -f2)
        local last_used
        last_used=$(nmcli -t -f connection.timestamp connection show id "$name" 2>/dev/null | cut -d: -f2)
        if [ -n "$last_used" ] && [ "$last_used" != "0" ]; then
            last_used=$(date -d "@$last_used" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "unknown")
        else
            last_used="never"
        fi
        local auto_icon
        auto_icon=$([ "$autoconnect" = "yes" ] && echo "󰁪" || echo "󰁮")
        # Detect enterprise
        local ent_tag=""
        local conn_eap
        conn_eap=$(nmcli -t -f 802-1x.eap connection show id "$name" 2>/dev/null | cut -d: -f2)
        [ -n "$conn_eap" ] && ent_tag=" 󰈸"
        log_debug "  Saved: '$name' auto=$autoconnect last=$last_used eap=$conn_eap"
        menu+="$(printf "%s  %-25s%s  Last: %s" "$auto_icon" "$name" "$ent_tag" "$last_used")"$'\n'
    done

    local header="Auto  Network                    Last Used"
    local selection
    selection=$(printf "  Back\n%s" "$menu" | rofi_menu -p "󰆓 Saved Networks" -mesg "$header")

    [ -z "$selection" ] || [[ "$selection" == *"Back"* ]] && return

    local net_name
    net_name=$(echo "$selection" | sed 's/^[^ ]* *//' | sed 's/ 󰈸//' | sed 's/\s*Last:.*$//' | sed 's/\s*$//')
    log_info "Selected saved network: '$net_name'"

    # Check if enterprise
    local is_ent
    is_ent=$(nmcli -t -f 802-1x.eap connection show id "$net_name" 2>/dev/null | cut -d: -f2)

    local menu_items="  Connect\n  Forget\n  Toggle Auto-connect\n  Change DNS\n  Back"
    [ -n "$is_ent" ] && menu_items="  Connect\n  802.1X Settings\n  Forget\n  Toggle Auto-connect\n  Change DNS\n  Back"

    local action
    action=$(printf "$menu_items" | rofi_menu -p "$net_name")

    log_info "Saved network action: '$action'"

    case "$action" in
        *"Connect")
            log_info "Connecting to saved network '$net_name'"
            nmcli connection up id "$net_name" >"$LOG_FILE" 2>&1
            if grep -q "successfully activated" "$LOG_FILE"; then
                log_ok "Connected to '$net_name'"
                notify "Connected to $net_name"
            else
                local err
                err=$(tail -1 "$LOG_FILE")
                log_error "Failed to connect to '$net_name': $err"
                rofi_msg "Failed: $err"
            fi
            ;;
        *"802.1X Settings"*)
            edit_enterprise_settings "$net_name"
            ;;
        *"Forget")
            local confirm
            confirm=$(printf "Yes, forget\nCancel" | rofi_menu -p "Forget $net_name?")
            if [ "$confirm" = "Yes, forget" ]; then
                log_info "Forgetting saved network '$net_name'"
                run_cmd "Forget $net_name" nmcli connection delete id "$net_name"
                notify "Forgot: $net_name"
            fi
            ;;
        *"Toggle Auto-connect")
            toggle_autoconnect "$net_name"
            ;;
        *"Change DNS")
            change_dns "$net_name"
            ;;
    esac
}

# ─── Hotspot Mode ───────────────────────────────────────────────────

manage_hotspot() {
    local wifi_dev
    wifi_dev=$(get_wifi_device)
    log_info "Managing hotspot on device '$wifi_dev'"

    local hotspot_active
    hotspot_active=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active | grep "802-11-wireless" | grep "Hotspot" | cut -d: -f1)

    if [ -n "$hotspot_active" ]; then
        log_info "Hotspot is active: '$hotspot_active'"
        local action
        action=$(printf "  Stop Hotspot\n  Show QR Code\n  Back" | rofi_menu -p "󱜠 Hotspot Active")
        case "$action" in
            *"Stop Hotspot")
                log_info "Stopping hotspot '$hotspot_active'"
                run_cmd "Stop hotspot" nmcli connection down id "$hotspot_active"
                notify "Hotspot stopped"
                ;;
            *"Show QR Code")
                local hp_ssid hp_pass
                hp_ssid=$(nmcli -t -f 802-11-wireless.ssid connection show id "$hotspot_active" 2>/dev/null | cut -d: -f2)
                hp_pass=$(nmcli -s -t -f 802-11-wireless-security.psk connection show id "$hotspot_active" 2>/dev/null | cut -d: -f2)
                log_debug "Hotspot SSID=$hp_ssid (password hidden)"
                if command -v qrencode >/dev/null 2>&1; then
                    qrencode -t PNG -o /tmp/hotspot-qr.png "WIFI:T:WPA;S:${hp_ssid};P:${hp_pass};;"
                    log_ok "QR code generated at /tmp/hotspot-qr.png"
                    notify "QR code saved to /tmp/hotspot-qr.png"
                    xdg-open /tmp/hotspot-qr.png 2>/dev/null &
                else
                    log_warn "qrencode not installed, showing text instead"
                    rofi_msg "SSID: $hp_ssid\nPassword: $hp_pass\n\n(Install qrencode for QR code)"
                fi
                ;;
        esac
        return
    fi

    log_info "No active hotspot, creating new one"
    local hp_ssid
    hp_ssid=$(rofi_menu -p "Hotspot SSID" <<< "$(hostname)")
    [ -z "$hp_ssid" ] && { log_debug "Hotspot creation cancelled (no SSID)"; return; }

    local hp_pass
    hp_pass=$(rofi_menu -password -p "Hotspot Password (8+ chars)")
    [ -z "$hp_pass" ] && { log_debug "Hotspot creation cancelled (no password)"; return; }
    if [ ${#hp_pass} -lt 8 ]; then
        log_error "Hotspot password too short (${#hp_pass} chars)"
        rofi_msg "Password must be at least 8 characters."
        return
    fi

    log_info "Creating hotspot: SSID='$hp_ssid' on '$wifi_dev'"
    nmcli dev wifi hotspot ifname "$wifi_dev" ssid "$hp_ssid" password "$hp_pass" >"$LOG_FILE" 2>&1
    if grep -q "successfully activated" "$LOG_FILE"; then
        log_ok "Hotspot '$hp_ssid' started successfully"
        notify "Hotspot '$hp_ssid' started"
    else
        local err
        err=$(tail -1 "$LOG_FILE")
        log_error "Hotspot creation failed: $err"
        rofi_msg "Hotspot failed: $err"
    fi
}

# ─── Network Diagnostics ────────────────────────────────────────────

network_diagnostics() {
    log_info "Opening network diagnostics"

    local action
    action=$(printf "  Ping Test (Google)\n  Ping Test (Cloudflare)\n  Show IP (public)\n  Show IP (local)\n  DNS Lookup Test\n  Traceroute\n  NetworkManager Logs\n  Back" \
        | rofi_menu -p "󰒍 Diagnostics")

    log_info "Diagnostics action: '$action'"

    case "$action" in
        *"Ping Test (Google)"*)
            notify "Pinging google.com..."
            log_info "Running ping test to google.com"
            local result
            result=$(ping -c 4 -W 2 google.com 2>&1)
            log_debug "Ping result: $(echo "$result" | tail -2)"
            rofi_msg "$(echo "$result" | tail -3)"
            ;;
        *"Ping Test (Cloudflare)"*)
            notify "Pinging 1.1.1.1..."
            log_info "Running ping test to 1.1.1.1"
            local result
            result=$(ping -c 4 -W 2 1.1.1.1 2>&1)
            log_debug "Ping result: $(echo "$result" | tail -2)"
            rofi_msg "$(echo "$result" | tail -3)"
            ;;
        *"Show IP (public)"*)
            notify "Fetching public IP..."
            log_info "Fetching public IP"
            local pub_ip
            pub_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "Failed to fetch")
            log_info "Public IP: $pub_ip"
            local geo
            geo=$(curl -s --max-time 5 "ipinfo.io/$pub_ip/json" 2>/dev/null \
                | grep -oP '"(city|region|country|org)":\s*"\K[^"]+' \
                | paste -sd ', ' -)
            log_debug "Geo info: $geo"
            rofi_msg "Public IP: $pub_ip\nLocation: ${geo:-unknown}"
            ;;
        *"Show IP (local)"*)
            local wifi_dev
            wifi_dev=$(get_wifi_device)
            local local_ip
            local_ip=$(nmcli -t -f IP4.ADDRESS dev show "$wifi_dev" 2>/dev/null | head -1 | cut -d: -f2)
            log_info "Local IP: ${local_ip:-not connected}"
            rofi_msg "Local IP: ${local_ip:-not connected}\nDevice: ${wifi_dev:-unknown}"
            ;;
        *"DNS Lookup Test"*)
            log_info "Running DNS lookup tests"
            notify "Testing DNS resolution..."
            local dns_result=""
            for domain in google.com cloudflare.com github.com; do
                local start end elapsed resolved
                start=$(date +%s%N)
                resolved=$(dig +short "$domain" 2>/dev/null | head -1)
                end=$(date +%s%N)
                elapsed=$(( (end - start) / 1000000 ))
                dns_result+="$domain → ${resolved:-FAILED} (${elapsed}ms)\n"
                log_debug "DNS: $domain → ${resolved:-FAILED} (${elapsed}ms)"
            done
            rofi_msg "$(echo -e "DNS Resolution Test:\n$dns_result")"
            ;;
        *"Traceroute"*)
            local target
            target=$(rofi_menu -p "Traceroute to (host/IP)" <<< "google.com")
            [ -z "$target" ] && return
            log_info "Running traceroute to '$target'"
            notify "Traceroute to $target (this may take a moment)..."
            local trace_result
            if command -v traceroute >/dev/null 2>&1; then
                trace_result=$(traceroute -m 15 -w 2 "$target" 2>&1)
            elif command -v mtr >/dev/null 2>&1; then
                trace_result=$(mtr -r -c 3 "$target" 2>&1)
            else
                trace_result="Neither traceroute nor mtr found.\nInstall with: sudo pacman -S traceroute"
                log_error "No traceroute tool found"
            fi
            log_debug "Traceroute complete"
            rofi_msg "$trace_result"
            ;;
        *"NetworkManager Logs"*)
            log_info "Fetching recent NetworkManager logs"
            local nm_logs
            nm_logs=$(journalctl -u NetworkManager --no-pager -n 30 --output=short-iso 2>/dev/null \
                || echo "Could not fetch logs (try running as root)")
            rofi_msg "$nm_logs"
            ;;
    esac
}

# ─── Main Flow ───────────────────────────────────────────────────────


log_info "═══ Starting main flow ═══"

# Batch initial state queries into parallel subshells
WIFI_STATE=$(nmcli radio wifi)
wifi_dev_cache=$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
_CACHED_WIFI_DEVICE="$wifi_dev_cache"

if [ "$WIFI_STATE" = "disabled" ]; then
    log_warn "WiFi is disabled"
    CHOICE=$(printf "  Enable WiFi\n  Cancel" | rofi_menu -p "󰤮 WiFi Disabled")
    if [[ "$CHOICE" == *"Enable WiFi"* ]]; then
        log_info "Enabling WiFi radio"
        run_cmd "Enable WiFi" nmcli radio wifi on
        notify "WiFi enabled"
    else
        log_info "User cancelled, exiting"
        exit 0
    fi
fi

# Get active connections in parallel
wired_connected=""
CURRENT_SSID=""

# Fast: check active connections only
active_cons=$(nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null)

# Extract WiFi SSID
CURRENT_SSID=$(echo "$active_cons" | awk -F: '$2=="802-11-wireless" {print $1; exit}')

# Extract wired device (optional)
wired_connected=$(echo "$active_cons" | awk -F: '$2=="802-3-ethernet" {print $3; exit}')

[ -n "$wired_connected" ] && log_info "Wired connection detected: $wired_connected"
# ─── Connected Menu ─────────────────────────────────────────────────

if [ -n "$CURRENT_SSID" ]; then
    log_info "Currently connected to '$CURRENT_SSID'"
    wifi_dev=$(get_wifi_device)

    # Only show wired if it's actually a DIFFERENT device than wifi
    wired_note=""
    if [ -n "$wired_connected" ] && [ "$wired_connected" != "$wifi_dev" ]; then
        wired_note="\n  Also wired: $wired_connected"
    fi

    # Single call for connection enterprise info
    _conn_info=$(nmcli -t -f 802-1x.eap,802-1x.identity connection show id "$CURRENT_SSID" 2>/dev/null)
    conn_eap=$(echo "$_conn_info" | grep '^802-1x.eap' | cut -d: -f2)
    conn_identity=$(echo "$_conn_info" | grep '^802-1x.identity' | cut -d: -f2)

    STATUS_LINE="$sig_icon  $CURRENT_SSID"
    [ -n "$conn_eap" ] && STATUS_LINE+=$'\n'"  Auth: 802.1X ($conn_eap)  │  User: $conn_identity"
    STATUS_LINE+="$wired_note"

    menu_items="  $CURRENT_SSID (connected)\n  Connection Details\n  Switch Network\n  Disconnect\n  Saved Networks\n  Hotspot\n  Diagnostics\n  Change DNS\n  Disable WiFi"
    [ -n "$conn_eap" ] && menu_items="  $CURRENT_SSID (connected)\n  Connection Details\n  802.1X Settings\n  Switch Network\n  Disconnect\n  Saved Networks\n  Hotspot\n  Diagnostics\n  Change DNS\n  Disable WiFi"

    CHOICE=$(printf "$menu_items" | rofi_menu -p "󰤨 WiFi" -mesg "$(echo -e "$STATUS_LINE")")

    log_info "Connected menu choice: '$CHOICE'"

    case "$CHOICE" in
        *"$CURRENT_SSID"*"connected"*)
            show_connection_details "$CURRENT_SSID"
            exit 0
            ;;
        *"Connection Details"*)
            show_connection_details "$CURRENT_SSID"
            exit 0
            ;;
        *"802.1X Settings"*)
            edit_enterprise_settings "$CURRENT_SSID"
            exit 0
            ;;
        *"Switch Network"*)
            log_info "Switching network — falling through to scan"
            ;;
        *"Disconnect")
            log_info "Disconnecting from '$CURRENT_SSID'"
            nmcli connection down id "$CURRENT_SSID" 2>/dev/null \
                || nmcli dev disconnect "$wifi_dev" 2>/dev/null
            notify "Disconnected from $CURRENT_SSID"
            exit 0
            ;;
        *"Saved Networks"*)
            manage_saved_networks
            exit 0
            ;;
        *"Hotspot"*)
            manage_hotspot
            exit 0
            ;;
        *"Diagnostics"*)
            network_diagnostics
            exit 0
            ;;
        *"Change DNS"*)
            change_dns "$CURRENT_SSID"
            exit 0
            ;;
        *"Disable WiFi"*)
            log_info "Disabling WiFi radio"
            run_cmd "Disable WiFi" nmcli radio wifi off
            notify "WiFi disabled"
            exit 0
            ;;
        *)
            log_info "No selection, exiting"
            exit 0
            ;;
    esac
fi

# ─── Not Connected — Scan & Connect ─────────────────────────────────

log_info "Not connected — entering scan loop"

while true; do
    LIST=$(wifi_list)
    HEADER="Signal  Security     Network                      Strength  Type   Band"

    SELECTION=$(printf "%s\n%s" \
        "$(printf "  Rescan\n  Hidden Network\n  Enterprise Network (802.1X)\n  Saved Networks\n  Hotspot\n  Diagnostics\n  Disable WiFi")" \
        "$LIST" \
        | rofi_menu -p "󰤯 Select WiFi" -mesg "$HEADER")
    [ -z "$SELECTION" ] && { log_info "No selection, exiting"; exit 0; }

    log_info "Selection: '$SELECTION'"

    case "$SELECTION" in
        *"Rescan"*)
            log_info "Manual rescan requested"
            notify "Rescanning..."
            nmcli dev wifi rescan 2>/dev/null
            # sleep 2
            continue
            ;;
        *"Hidden Network"*)
            SSID=$(rofi_menu -p "Enter hidden SSID")
            [ -z "$SSID" ] && { log_debug "Hidden SSID cancelled"; continue; }
            log_info "Hidden network SSID entered: '$SSID'"
            # Ask if hidden network is enterprise
            local hidden_type
            hidden_type=$(printf "WPA Personal (password)\nWPA Enterprise (802.1X)\nOpen (no password)" \
                | rofi_menu -p "Auth type for $SSID")
            case "$hidden_type" in
                *"Enterprise"*)
                    connect_enterprise "$SSID"
                    [ $? -eq 0 ] && exit 0
                    continue
                    ;;
                *"Open"*)
                    nmcli dev wifi connect "$SSID" hidden yes >"$LOG_FILE" 2>&1
                    if grep -q "successfully activated" "$LOG_FILE"; then
                        notify "Connected to $SSID (hidden/open)"
                        exit 0
                    else
                        rofi_msg "Failed:\n$(tail -1 "$LOG_FILE")"
                    fi
                    continue
                    ;;
                *)
                    # Fall through to password prompt below
                    ;;
            esac
            ;;
        *"Enterprise Network"*)
            log_info "Manual Enterprise network entry"
            SSID=$(rofi_menu -p "Enterprise SSID" \
                -mesg "Enter the SSID of the 802.1X network")
            [ -z "$SSID" ] && { log_debug "Enterprise SSID cancelled"; continue; }
            connect_enterprise "$SSID"
            [ $? -eq 0 ] && exit 0
            continue
            ;;
        *"Saved Networks"*)
            manage_saved_networks
            continue
            ;;
        *"Hotspot"*)
            manage_hotspot
            continue
            ;;
        *"Diagnostics"*)
            network_diagnostics
            continue
            ;;
        *"Disable WiFi"*)
            log_info "Disabling WiFi radio"
            run_cmd "Disable WiFi" nmcli radio wifi off
            notify "WiFi disabled"
            exit 0
            ;;
        *)
            SSID=$(extract_ssid "$SELECTION")
            ;;
    esac

    [ -z "$SSID" ] && { log_warn "Empty SSID after extraction, retrying"; continue; }

    log_info "Attempting to connect to '$SSID'"

    # Detect if this is an enterprise network from the scan
    local net_security
    net_security=$(nmcli -t -f SSID,SECURITY dev wifi | grep "^${SSID}:" | head -1 | cut -d: -f2)
    log_debug "Network security for '$SSID': '$net_security'"

    if is_enterprise "$net_security"; then
        log_info "Enterprise network detected from scan for '$SSID'"
        # Check for existing saved profile
        if nmcli -t -f NAME connection show | grep -qx "$SSID"; then
            log_info "Found saved Enterprise profile for '$SSID', attempting connection"
            notify "Connecting to $SSID (Enterprise)..."
            nmcli connection up id "$SSID" >"$LOG_FILE" 2>&1
            if grep -q "successfully activated" "$LOG_FILE"; then
                log_ok "Connected to Enterprise '$SSID' via saved profile"
                notify "Connected to $SSID"
                exit 0
            else
                local err
                err=$(tail -1 "$LOG_FILE")
                log_error "Saved Enterprise profile failed: $err"
                local retry_choice
                retry_choice=$(printf "  Re-enter credentials\n  Edit 802.1X settings\n  Cancel" \
                    | rofi_menu -p "Enterprise Failed" -mesg "$err")
                case "$retry_choice" in
                    *"Re-enter"*)
                        nmcli connection delete id "$SSID" >/dev/null 2>&1
                        connect_enterprise "$SSID"
                        [ $? -eq 0 ] && exit 0
                        ;;
                    *"Edit"*)
                        edit_enterprise_settings "$SSID"
                        ;;
                esac
                continue
            fi
        else
            connect_enterprise "$SSID"
            [ $? -eq 0 ] && exit 0
            continue
        fi
    fi

    # Try saved profile first (for non-enterprise)
    if nmcli -t -f NAME connection show | grep -qx "$SSID"; then
        log_info "Found saved profile for '$SSID', attempting connection"
        notify "Connecting to $SSID..."
        nmcli connection up id "$SSID" >"$LOG_FILE" 2>&1
        if grep -q "successfully activated" "$LOG_FILE"; then
            log_ok "Connected to '$SSID' via saved profile"
            notify "Connected to $SSID"
            exit 0
        else
            local err
            err=$(tail -1 "$LOG_FILE")
            log_error "Saved profile failed for '$SSID': $err"
            rofi_msg "Saved profile failed:\n$err\n\nTrying with password..."
        fi
    else
        log_debug "No saved profile for '$SSID'"
    fi

    # Check if network is open
    if [ -z "$net_security" ] || [ "$net_security" = "--" ]; then
        log_info "Open network detected, connecting without password"
        nmcli dev wifi connect "$SSID" >"$LOG_FILE" 2>&1
        if grep -q "successfully activated" "$LOG_FILE"; then
            log_ok "Connected to '$SSID' (open)"
            notify "Connected to $SSID (open)"
            exit 0
        else
            local err
            err=$(tail -1 "$LOG_FILE")
            log_error "Open network connection failed: $err"
            rofi_msg "Connection failed:\n$err"
            continue
        fi
    fi

    # Prompt for password (WPA Personal)
    log_info "Prompting for password for '$SSID'"
    PASS=$(rofi_menu -password -p "󰌷 Password for $SSID")
    [ -z "$PASS" ] && { log_debug "Password prompt cancelled"; continue; }

    log_info "Connecting to '$SSID' with password"
    notify "Connecting to $SSID..."
    nmcli dev wifi connect "$SSID" password "$PASS" >"$LOG_FILE" 2>&1
    if grep -q "successfully activated" "$LOG_FILE"; then
        log_ok "Connected to '$SSID' with password"
        notify "Connected to $SSID"
        exit 0
    else
        local err
        err=$(tail -1 "$LOG_FILE")
        log_error "Connection with password failed for '$SSID': $err"
        local retry
        retry=$(printf "  Retry\n  Cancel" | rofi_menu -p "Connection Failed" -mesg "$err")
        [[ "$retry" == *"Retry"* ]] && { log_info "User chose to retry"; continue; }
        log_info "User cancelled retry"
    fi
done