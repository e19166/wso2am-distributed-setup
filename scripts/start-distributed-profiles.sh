#!/bin/bash

# Enhanced script to start WSO2 API Manager distributed profiles with port checking
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
COMPONENTS_DIR="$BASE_DIR/components"

# Start profiles in order: tm -> cp -> gw (Traffic Manager first, then Control Plane, then Gateway)
PROFILES=("tm" "cp" "gw")
PROFILE_NAMES=("Traffic Manager" "Control Plane" "Gateway Worker")

# Function to get ports for a profile
get_profile_ports() {
    case $1 in
        "tm") echo "9713" ;;  # 9711 + 2 (offset for TM)
        "cp") echo "9443 9444" ;;  # Control Plane: publisher and devportal (offset 0)
        "gw") echo "8281 8244" ;;  # Gateway: HTTP and HTTPS (offset 1: 8280+1, 8243+1)
        *) echo "" ;;
    esac
}

# Function to check if a port is available
check_port_available() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 1  # Port is in use
    else
        return 0  # Port is available
    fi
}

# Function to check if service is up on port
check_service_up() {
    local port=$1
    local timeout=${2:-60}  # Default 60 seconds timeout
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            return 0  # Service is up
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    return 1  # Service didn't come up within timeout
}

# Function to check all required ports before starting
check_ports_before_start() {
    echo "🔍 Checking port availability..."
    local all_available=true
    local occupied_ports=()
    
    for i in "${!PROFILES[@]}"; do
        profile="${PROFILES[i]}"
        profile_name="${PROFILE_NAMES[i]}"
        ports=$(get_profile_ports $profile)
        
        for port in $ports; do
            if ! check_port_available $port; then
                occupied_ports+=("$port ($profile_name)")
                all_available=false
            fi
        done
    done
    
    if [ "$all_available" = false ]; then
        echo "❌ Cannot start - ports already in use:"
        for port_info in "${occupied_ports[@]}"; do
            echo "   • $port_info"
        done
        echo ""
        echo "💡 Run 'scripts/stop-distributed-profiles.sh' first to stop existing services"
        exit 1
    fi
    
    echo "✅ All required ports are available"
    echo ""
}

echo "🚀 Starting WSO2 API Manager distributed profiles..."

# Check port availability before starting
check_ports_before_start

# Array to track started services for verification
declare -a STARTED_SERVICES

for i in "${!PROFILES[@]}"; do
    profile="${PROFILES[i]}"
    profile_name="${PROFILE_NAMES[i]}"
    profile_dir="$COMPONENTS_DIR/wso2am-$profile"
    
    if [ -d "$profile_dir" ]; then
        echo "⏳ Starting $profile_name..."
        cd "$profile_dir"
        # Determine the profile flag
        case $profile in
            "tm") profile_flag="traffic-manager" ;;
            "cp") profile_flag="control-plane" ;;
            "gw") profile_flag="gateway-worker" ;;
        esac
        nohup sh bin/api-manager.sh -Dprofile=$profile_flag > "$BASE_DIR/logs/startup-$profile.log" 2>&1 &
        echo $! > "$profile.pid"
        echo "   Started with PID: $(cat $profile.pid)"
        
        # Add to started services for verification
        STARTED_SERVICES+=("$profile")
        
        sleep 10  # Wait between starts
    else
        echo "⚠️  Warning: $profile_dir not found"
    fi
done

echo ""
echo "🔄 Verifying services are running..."

# Verify each started service is up
all_services_up=true
for i in "${!STARTED_SERVICES[@]}"; do
    profile="${STARTED_SERVICES[i]}"
    # Find the profile index
    for j in "${!PROFILES[@]}"; do
        if [[ "${PROFILES[j]}" == "$profile" ]]; then
            profile_name="${PROFILE_NAMES[j]}"
            break
        fi
    done
    ports=$(get_profile_ports $profile)
    
    profile_up=true
    for port in $ports; do
        if ! check_service_up $port 10; then  # 10 second timeout per port
            profile_up=false
            all_services_up=false
        fi
    done
    
    if [ "$profile_up" = true ]; then
        echo "✅ $profile_name"
    else
        echo "❌ $profile_name (check logs/startup-$profile.log)"
    fi
done

echo ""
if [ "$all_services_up" = true ]; then
    echo "🎉 All services started successfully!"
else
    echo "⚠️  Some services may not have started properly"
fi

echo ""
echo "📋 Service URLs:"
echo "   • Traffic Manager:  https://localhost:9713/carbon"
echo "   • Control Plane:    https://localhost:9443/publisher"
echo "                      https://localhost:9443/devportal"
echo "   • Gateway Worker:   https://localhost:8281 (HTTP) / https://localhost:8244 (HTTPS)"
echo ""
echo "📁 Logs available in: logs/"
