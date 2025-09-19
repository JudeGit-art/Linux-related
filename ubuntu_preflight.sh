#!/bin/bash
# v1.7 (Ubuntu modified - Server Overview)

old_OS_check () {
    if [ -e /etc/os-release ]; then
        . /etc/os-release
        echo -e "\n>> Operating System: $PRETTY_NAME"
        if [[ "$ID" == "ubuntu" ]]; then
            os_version=$(echo "$VERSION_ID" | cut -d. -f1)
            case $os_version in
                16)
                    echo "!! Ubuntu 16.x detected. This is EOL. Migration recommended."
                    os=ubuntu16
                    ;;
                18) os=ubuntu18 ;;
                20) os=ubuntu20 ;;
                22) os=ubuntu22 ;;
                *)  os=unknown ;;
            esac
        fi
    fi
    export os
}

identify_control_panel() {
    panel_count=0
    control_panel="none"

    if grep -q "cpanel:x:" /etc/passwd; then
        control_panel=cpanel
        ((panel_count++))
    fi
    if grep -q "iworx:x:" /etc/passwd; then
        control_panel=interworx
        ((panel_count++))
    fi
    if grep -q "psaadm:x:" /etc/passwd; then
        control_panel=plesk
        ((panel_count++))
    fi

    echo -e "\n>> Control Panel Detection:"
    if [ "$panel_count" -gt 1 ]; then
        echo "!! Multiple control panels detected. Results may be inaccurate."
    elif [ "$panel_count" -eq 0 ]; then
        echo "No control panel software found."
    else
        echo "Detected: $control_panel"
    fi
    export control_panel
}

check_cronjobs() {
    echo -e "\n>> Cron Job Inspection (looking for 'base64' in files):"
    cron_paths=(
        "/var/spool/cron/crontabs/"
        "/etc/cron.d/"
        "/etc/cron.daily/"
        "/etc/cron.hourly/"
        "/etc/cron.weekly/"
        "/etc/cron.monthly/"
    )

    for path in "${cron_paths[@]}"; do
        if [ -d "$path" ]; then
            files=$(grep -rl base64 "$path" 2>/dev/null)
            if [ -n "$files" ]; then
                echo "Suspicious 'base64' usage found in: $path"
                while IFS= read -r file; do
                    # Using modification time (last write)
                    mod_time=$(stat -c '%y' "$file")
                    echo "$file - Last Modified: $mod_time"
                done <<< "$files"
            fi
        fi
    done
}

check_docker() {
    if [[ "$os" =~ ubuntu ]]; then
        echo -e "\n>> Docker Check:"
        if command -v docker &>/dev/null; then
            echo "Docker is installed."
            docker --version
        else
            echo "Docker is NOT installed."
        fi
    fi
}

root_ssh_logins() {
    echo -e "\n>> SSH Root Login Overview:"
    echo "Last password change for root:"
    chage -l root | grep "Last password change" | head -n1

    echo -e "\nUsers in 'sudo' group:"
    getent group sudo

    echo -e "\nUsers with UID 0 (root access):"
    awk -F: '$3 == 0 { print $1 }' /etc/passwd

    echo -e "\nRoot SSH logins by IP (from /var/log/auth.log*):"
    zgrep 'sshd.*Accepted.*root' /var/log/auth.log* 2>/dev/null | \
    awk '{for (i=1;i<=NF;i++) if ($i=="from") print $(i+1)}' | \
    sort | uniq -c | sort -rn
}

system_info() {
    echo -e "\n>> General System Info:"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
    echo "Load Average: $(cat /proc/loadavg)"

    echo -e "\nListening Services on Port 25:"
    ss -tulnp | grep 25 || echo "No services listening on port 25."
}

main() {
    echo -e "\n===== SERVER OVERVIEW REPORT ====="
    echo -e "Generated on: $(date)"
    old_OS_check
    identify_control_panel
    root_ssh_logins
    check_cronjobs
    check_docker
    system_info
    echo -e "\n===== END OF REPORT =====\n"
}

main
