#!/bin/bash

# Script to check status of WSO2 API Manager distributed profiles
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENTS_DIR="$BASE_DIR/components"

# Profiles and their ports
PROFILES=("tm" "cp" "gw")
PROFILE_NAMES=("Traffic Manager" "Control Plane" "Gateway Worker")

# Function to get ports for a profile
get_profile_ports() {
    case $1 in
        "tm") echo "9711" ;;
        "cp") echo "9443 9444" ;;
    "gw") echo "8281 8244" ;;
        *) echo "" ;;
    esac
}

echo "📊 WSO2 API Manager Distributed Profiles Status"
echo "=============================================="

running_count=0
for i in "${!PROFILES[@]}"; do
    profile="${PROFILES[i]}"
    profile_name="${PROFILE_NAMES[i]}"
    profile_dir="$COMPONENTS_DIR/wso2am-$profile"
    pid_file="$profile_dir/$profile.pid"
    ports=$(get_profile_ports $profile)
    
    echo ""
    echo "🔹 $profile_name:"
    
    # Check PID file
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo "   📍 Process: Running (PID: $pid)"
        else
            echo "   📍 Process: Not running (stale PID file)"
        fi
    else
        echo "   📍 Process: No PID file"
    fi
    
    # Check ports
    service_running=false
    for port in $ports; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo "   🌐 Port $port: ✅ Active"
            service_running=true
        else
            echo "   🌐 Port $port: ❌ Not listening"
        fi
    done
    
    if [ "$service_running" = true ]; then
        running_count=$((running_count + 1))
    fi
done

echo ""
echo "=============================================="
if [ $running_count -eq 0 ]; then
    echo "🚫 No services are currently running"
    echo ""
    echo "💡 To start services: scripts/start-distributed-profiles.sh"
elif [ $running_count -eq 5 ]; then
    echo "✅ All $running_count services are running"
    echo ""
    echo "🌐 Service URLs:"
    echo "   • Traffic Manager:  https://localhost:9711/carbon"
    echo "   • Key Manager:      https://localhost:9443/carbon"  
    echo "   • Publisher:        https://localhost:9445/publisher"
    echo "   • Developer Portal: https://localhost:9446/devportal"
    echo "   • Gateway:          https://localhost:8284 (HTTP) / https://localhost:8247 (HTTPS)"
else
    echo "⚠️  $running_count out of 5 services are running"
    echo ""
    echo "💡 To stop services: scripts/stop-distributed-profiles.sh"
    echo "💡 To start services: scripts/start-distributed-profiles.sh"
fi
echo ""
