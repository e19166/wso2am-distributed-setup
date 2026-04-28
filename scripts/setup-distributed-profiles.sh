#!/bin/bash

# WSO2 API Manager distributed profiles setup script
# Requires extracted and updated WSO2 APIM pack in root directory
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Validate WSO2AM extracted directory exists
echo "🔍 Validating WSO2 APIM installation..."

SOURCE_DIR=""
for dir in "$BASE_DIR"/wso2am-*; do
    if [ -d "$dir" ] && [ -f "$dir/bin/wso2server.sh" ]; then
        SOURCE_DIR="$dir"
        echo "✅ Found WSO2 APIM at: $(basename "$dir")"
        break
    fi
done

if [ -z "$SOURCE_DIR" ]; then
    echo "❌ Error: WSO2 API Manager directory not found!"
    echo "Place extracted WSO2 APIM folder (wso2am-3.2.0/) in project root"
    exit 1
fi

COMPONENTS_DIR="$BASE_DIR/components"
PROFILES=("km" "tm" "dev" "pub" "gw")

ensure_synapse_inbound_endpoints() {
    local target_dir="$1"
    local source_dir="$2"

    # Some profileSetup combinations remove the Synapse inbound-endpoints dir or
    # specific inbound endpoint XMLs. Config-mapper then fails while reading
    # metadata at startup.
    local target_inbound="$target_dir/repository/deployment/server/synapse-configs/default/inbound-endpoints"
    local source_inbound="$source_dir/repository/deployment/server/synapse-configs/default/inbound-endpoints"

    mkdir -p "$target_inbound"

    if [ -d "$source_inbound" ]; then
        # If dir is empty, copy everything.
        if [ -z "$(ls -A "$target_inbound" 2>/dev/null)" ]; then
            cp -n "$source_inbound"/*.xml "$target_inbound"/ 2>/dev/null || true
        fi

        # Ensure the two commonly referenced files always exist.
        for f in WebSocketInboundEndpoint.xml SecureWebSocketInboundEndpoint.xml; do
            if [ -f "$source_inbound/$f" ] && [ ! -f "$target_inbound/$f" ]; then
                cp "$source_inbound/$f" "$target_inbound/" 2>/dev/null || true
            fi
        done
    fi
}

ensure_axis2_blocking_client() {
    local target_dir="$1"
    local source_dir="$2"

    local target_file="$target_dir/repository/conf/axis2/axis2_blocking_client.xml"
    local source_file="$source_dir/repository/conf/axis2/axis2_blocking_client.xml"

    if [ ! -f "$target_file" ] && [ -f "$source_file" ]; then
        mkdir -p "$(dirname "$target_file")"
        cp "$source_file" "$target_file" 2>/dev/null || true
    fi
}

# Setup MySQL connector
setup_mysql_connector() {
    local target_dir="$1"
    local mysql_source="$BASE_DIR/conf/mysql-connector-j-9.2.0.jar"
    local target_lib_dir="$target_dir/repository/components/lib"
    
    if [ -f "$mysql_source" ]; then
        mkdir -p "$target_lib_dir"
        cp "$mysql_source" "$target_lib_dir/"
        rm -f "$target_dir/repository/components/dropins/mysql"*
        echo "MySQL connector setup complete"
    fi
}

# Main setup
echo "Setting up WSO2 API Manager distributed profiles..."
mkdir -p "$COMPONENTS_DIR"

for i in "${!PROFILES[@]}"; do
    profile="${PROFILES[i]}"
    target_dir="$COMPONENTS_DIR/wso2am-$profile"
    
    echo "Creating profile: $profile"
    
    # Copy source to target
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    cp -r "$SOURCE_DIR" "$target_dir"
    
    # Setup MySQL connector
    setup_mysql_connector "$target_dir"
    
    # Configure profile
    cd "$target_dir"
    chmod +x bin/profileSetup.sh
    case "$profile" in
        "km") sh bin/profileSetup.sh -Dprofile=api-key-manager ;;
        "tm") sh bin/profileSetup.sh -Dprofile=traffic-manager ;;
        "dev") sh bin/profileSetup.sh -Dprofile=api-devportal ;;
        "pub") sh bin/profileSetup.sh -Dprofile=api-publisher ;;
        "gw") sh bin/profileSetup.sh -Dprofile=gateway-worker ;;
    esac

    # Keep synapse inbound endpoints present for profiles that use config-mapper
    # against synapse-configs.
    case "$profile" in
        "km"|"tm"|"dev"|"pub") ensure_synapse_inbound_endpoints "$target_dir" "$SOURCE_DIR" ;;
    esac

    # Key manager profileSetup removes axis2_blocking_client.xml, but config-mapper
    # metadata can still reference it on startup.
    if [ "$profile" = "km" ]; then
        ensure_axis2_blocking_client "$target_dir" "$SOURCE_DIR"
    fi
    
    # Replace deployment.toml if custom config exists
    toml_source="$BASE_DIR/conf/toml/${profile}_deployment.toml"
    if [ -f "$toml_source" ]; then
        cp "$toml_source" "$target_dir/repository/conf/deployment.toml"
        echo "Custom deployment.toml applied"
    fi
done

echo "Setup complete! All profiles created in: $COMPONENTS_DIR"
