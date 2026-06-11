#!/usr/bin/env bash
# ==============================================================================
# Script Name:  health_check.sh
# Description:  Automated Server Health Check & Monitoring Tool
# Usage:        ./health_check.sh [-d disk_threshold] [-m ram_threshold] [-l log_file]
# ==============================================================================

set -uo pipefail # Safely exit on undefined variables, keep pipe errors

# --- Color Codes (Console only) ---
NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'

# --- Default Configurations ---
DISK_WARN_THRESHOLD=80  # in %
RAM_WARN_THRESHOLD=80   # in %
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="${PROJECT_DIR}/logs/health_check.log"
SERVICES_FILE="${PROJECT_DIR}/config/services.txt"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")"

# --- Helper Functions ---
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -d <percent>    Disk warning threshold (default: ${DISK_WARN_THRESHOLD}%)
  -m <percent>    RAM warning threshold (default: ${RAM_WARN_THRESHOLD}%)
  -l <file_path>  Custom path to output log file
  -s <file_path>  Custom path to services file
  -h, --help      Show this help message and exit

EOF
}

# Parse Command-Line Arguments
while getopts "d:m:l:s:h-" opt; do
    case "$opt" in
        d) DISK_WARN_THRESHOLD=$OPTARG ;;
        m) RAM_WARN_THRESHOLD=$OPTARG ;;
        l) LOG_FILE=$OPTARG ;;
        s) SERVICES_FILE=$OPTARG ;;
        h) show_help; exit 0 ;;
        -)
            case "$OPTARG" in
                help) show_help; exit 0 ;;
                *) echo -e "${RED}Unknown option --$OPTARG${NC}" >&2; show_help; exit 1 ;;
            esac
            ;;
        \?) show_help; exit 1 ;;
    esac
done

# Initialize run variables
SYSTEM_STATUS="OK"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)
OS_TYPE=$(uname -s)

# Create a temporary file to collect the report
REPORT_TMP=$(mktemp)

# Cleanup on exit
cleanup() {
    rm -f "$REPORT_TMP"
}
trap cleanup EXIT

# Formatting Output helper (writes to console with colors, and plain text to temp report)
log_info() {
    local category="$1"
    local message="$2"
    echo -e "${CYAN}[INFO]${NC} ${category}: ${message}"
    echo "[INFO] ${category}: ${message}" >> "$REPORT_TMP"
}

log_header() {
    local title="$1"
    echo -e "\n${BOLD}${BLUE}=== $title ===${NC}"
    echo -e "\n=== $title ===" >> "$REPORT_TMP"
}

log_result() {
    local status="$1" # OK, WARN, CRIT
    local message="$2"
    case "$status" in
        OK)
            echo -e "  [${GREEN}OK${NC}] $message"
            echo "  [OK] $message" >> "$REPORT_TMP"
            ;;
        WARN)
            echo -e "  [${YELLOW}WARNING${NC}] $message"
            echo "  [WARNING] $message" >> "$REPORT_TMP"
            [ "$SYSTEM_STATUS" = "OK" ] && SYSTEM_STATUS="WARNING"
            ;;
        CRIT)
            echo -e "  [${RED}CRITICAL${NC}] $message"
            echo "  [CRITICAL] $message" >> "$REPORT_TMP"
            SYSTEM_STATUS="CRITICAL"
            ;;
    esac
}

# --- 1. System Info & Uptime ---
log_header "SYSTEM INFO & UPTIME"
log_info "Host" "$HOSTNAME ($OS_TYPE)"

# Retrieve uptime elegantly
if [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    # Git Bash / Windows fallback
    UPTIME_INFO=$(powershell -NoProfile -Command "
        \$os = Get-CimInstance Win32_OperatingSystem;
        \$uptime = (Get-Date) - \$os.LastBootUpTime;
        Write-Output \"\$([Math]::Floor(\$uptime.TotalDays)) days, \$(\$uptime.Hours) hours, \$(\$uptime.Minutes) minutes\"
    " 2>/dev/null | tr -d '\r')
    [ -z "$UPTIME_INFO" ] && UPTIME_INFO="Unable to retrieve uptime via PowerShell"
else
    # Linux native
    UPTIME_INFO=$(uptime -p 2>/dev/null || uptime)
fi
log_info "Uptime" "$UPTIME_INFO"

# --- 2. CPU Load Check ---
log_header "CPU UTILIZATION"
CPU_LOAD=""
if [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    CPU_LOAD=$(powershell -NoProfile -Command "
        \$cpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average;
        Write-Output \$cpu.Average
    " 2>/dev/null | tr -d '\r')
fi

# Fallback or Linux CPU check
if [ -z "$CPU_LOAD" ]; then
    if [ -f /proc/loadavg ]; then
        CPU_LOAD=$(awk '{print $1}' /proc/loadavg)
        log_info "CPU Load (1m avg)" "$CPU_LOAD"
    else
        log_info "CPU Status" "Check not supported on this platform"
    fi
else
    log_info "CPU Load" "${CPU_LOAD}%"
fi

# --- 3. RAM Check ---
log_header "MEMORY (RAM) UTILIZATION"
USED_MB=0
TOTAL_MB=0
RAM_PERCENT=0

if command -v free >/dev/null 2>&1; then
    # Native Linux
    TOTAL_MB=$(free -m | awk 'NR==2{print $2}')
    USED_MB=$(free -m | awk 'NR==2{print $3}')
    RAM_PERCENT=$(( USED_MB * 100 / TOTAL_MB ))
elif [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
    # Windows/Git Bash fallback using PowerShell CIM
    MEM_STATS=$(powershell -NoProfile -Command "
        Get-CimInstance Win32_OperatingSystem | ForEach-Object {
            \$total = [Math]::Round(\$_.TotalVisibleMemorySize / 1024);
            \$free = [Math]::Round(\$_.FreePhysicalMemory / 1024);
            \$used = \$total - \$free;
            \$percent = [Math]::Round(\$used * 100 / \$total);
            Write-Output \"\$used,\$total,\$percent\"
        }
    " 2>/dev/null | tr -d '\r')
    
    if [ -n "$MEM_STATS" ]; then
        IFS=',' read -r USED_MB TOTAL_MB RAM_PERCENT <<< "$MEM_STATS"
    fi
fi

if [ "$TOTAL_MB" -gt 0 ]; then
    MSG="RAM Usage: ${USED_MB}MB / ${TOTAL_MB}MB (${RAM_PERCENT}%)"
    if [ "$RAM_PERCENT" -ge "$RAM_WARN_THRESHOLD" ]; then
        log_result "WARN" "$MSG (Threshold: ${RAM_WARN_THRESHOLD}%)"
    else
        log_result "OK" "$MSG"
    fi
else
    log_result "WARN" "Could not parse RAM stats on this environment."
fi

# --- 4. Disk Space Check ---
log_header "DISK SPACE UTILIZATION"
# Get disk usage, skipping table headers
# Note: df works in Git Bash for Windows drives too
df -h | grep -vE '^Filesystem|shm|udev|tmpfs|loop' | while read -r line; do
    # Parse fields from the end of the line to support filesystems with spaces
    percent=$(echo "$line" | awk '{print $(NF-1)}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $NF}')
    size=$(echo "$line" | awk '{print $(NF-4)}')
    used=$(echo "$line" | awk '{print $(NF-3)}')
    
    # Validate percent is numeric
    if [[ "$percent" =~ ^[0-9]+$ ]]; then
        MSG="Disk ${mount}: ${used}/${size} (${percent}% used)"
        if [ "$percent" -ge "$DISK_WARN_THRESHOLD" ]; then
            log_result "WARN" "$MSG (Threshold: ${DISK_WARN_THRESHOLD}%)"
        else
            log_result "OK" "$MSG"
        fi
    fi
done

# --- 5. Service Status Check ---
log_header "SERVICE MONITORING"
if [ -f "$SERVICES_FILE" ]; then
    # Read services while ignoring comments and empty lines
    while IFS= read -r service || [ -n "$service" ]; do
        # Strip trailing carriage returns if file was created on Windows
        service=$(echo "$service" | tr -d '\r' | xargs)
        [[ -z "$service" || "$service" =~ ^# ]] && continue

        STATUS_OK=false
        
        # Method 1: systemctl (Linux systemd)
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active "$service" >/dev/null 2>&1; then
                STATUS_OK=true
                log_result "OK" "Service '$service' is running (systemctl)"
            fi
        # Method 2: service (older Linux SysVinit)
        elif command -v service >/dev/null 2>&1; then
            if service "$service" status >/dev/null 2>&1; then
                STATUS_OK=true
                log_result "OK" "Service '$service' is running (service)"
            fi
        fi
        
        # Method 3: Process check (for environment without systemd or Git Bash compatibility)
        if [ "$STATUS_OK" = false ]; then
            # Search local process list (case-insensitive)
            if ps aux 2>/dev/null | grep -v grep | grep -iq "$service"; then
                STATUS_OK=true
                log_result "OK" "Service/Process '$service' is active in process list"
            elif [[ "$OS_TYPE" == *"MINGW"* || "$OS_TYPE" == *"MSYS"* ]]; then
                # On Windows Git Bash, also check Windows tasklist processes
                if tasklist 2>/dev/null | grep -iq "$service"; then
                    STATUS_OK=true
                    log_result "OK" "Windows Process '$service' is active in tasklist"
                fi
            fi
        fi
        
        # If all methods failed to verify it is running
        if [ "$STATUS_OK" = false ]; then
            log_result "CRIT" "Service '$service' is stopped or not found!"
        fi
        
    done < "$SERVICES_FILE"
else
    log_info "Services" "No services config file found at ${SERVICES_FILE}. Skipping services check."
fi

# --- 6. Summary and Logging ---
log_header "MONITORING SUMMARY"
COLOR_STATUS=$NC
case "$SYSTEM_STATUS" in
    OK) COLOR_STATUS=$GREEN ;;
    WARNING) COLOR_STATUS=$YELLOW ;;
    CRITICAL) COLOR_STATUS=$RED ;;
esac

echo -e "Overall System Health: ${BOLD}${COLOR_STATUS}${SYSTEM_STATUS}${NC}"
echo "Overall System Health: ${SYSTEM_STATUS}" >> "$REPORT_TMP"
echo -e "Report logged to: ${LOG_FILE}"

# Format full report to the file (adding headers and divider)
{
    echo "=========================================================================="
    echo "SERVER HEALTH MONITORING REPORT"
    echo "Timestamp: $TIMESTAMP"
    echo "Hostname:  $HOSTNAME"
    echo "Status:    $SYSTEM_STATUS"
    echo "=========================================================================="
    cat "$REPORT_TMP"
    echo -e "\n\n"
} >> "$LOG_FILE"

# Exit with code representing health status
if [ "$SYSTEM_STATUS" = "CRITICAL" ]; then
    exit 2
elif [ "$SYSTEM_STATUS" = "WARNING" ]; then
    exit 1
else
    exit 0
fi
