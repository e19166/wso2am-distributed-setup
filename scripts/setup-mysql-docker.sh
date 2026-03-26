#!/bin/bash

# Simple Docker MySQL setup for WSO2 API Manager
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables from .env file in root directory
if [[ -f "$BASE_DIR/.env" ]]; then
    echo "Loading configuration from .env file..."
    source "$BASE_DIR/.env"
else
    echo "Warning: .env file not found in root directory. Using default values."
    CONTAINER_NAME="wso2am-mysql"
    MYSQL_ROOT_PASSWORD="my-secret"
    MYSQL_PORT="3326"
fi

# Function to check if port is available or used by our container
check_port_availability() {
    local port=$1
    local container_name=$2
    
    # Check if port is in use
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "Port $port is currently in use."

        # If the container exists, check whether it's actually our container holding the port.
        # This is more reliable than parsing `docker ps` output (formatting differs across versions).
        if docker ps --format "{{.Names}}" | grep -E "^${container_name}$" >/dev/null 2>&1; then
            local mapped_port
            mapped_port=$(docker port "$container_name" 3306/tcp 2>/dev/null | awk -F: '{print $2}' | head -1)
            if [ -n "$mapped_port" ] && [ "$mapped_port" = "$port" ]; then
                echo "✓ Port $port is being used by our existing MySQL container '$container_name'"
                echo "This is expected behavior - the container is already running."
                return 0
            fi
        fi
        
        # Check if it's our MySQL container using the port
        if docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -E "^${container_name}\s.*:${port}->" >/dev/null 2>&1; then
            echo "✓ Port $port is being used by our existing MySQL container '$container_name'"
            echo "This is expected behavior - the container is already running."
            return 0
        else
            # Port is used by something else
            echo "❌ Error: Port $port is being used by a different process!"
            echo "Please check what's running on port $port:"
            lsof -Pi :$port -sTCP:LISTEN
            echo ""
            echo "You can:"
            echo "1. Change MYSQL_PORT in .env file to use a different port"
            echo "2. Stop the service using port $port"
            echo "3. Kill the process: sudo kill \$(lsof -t -i:$port)"
            exit 1
        fi
    else
        echo "✓ Port $port is available"
        return 0
    fi
}

# Function to validate container configuration against .env file
validate_container_configuration() {
    local container_name=$1
    
    if ! docker ps --format "{{.Names}}" | grep -E "^${container_name}$" >/dev/null 2>&1; then
        # Container doesn't exist, no validation needed
        return 0
    fi
    
    echo "🔍 Validating container configuration against .env file..."
    local config_mismatch=false
    
    # Check port mapping
    local actual_port=$(docker port "$container_name" 3306 2>/dev/null | cut -d: -f2)
    if [ -n "$actual_port" ] && [ "$actual_port" != "$MYSQL_PORT" ]; then
        echo "❌ Port mismatch: .env specifies $MYSQL_PORT, container uses $actual_port"
        config_mismatch=true
    fi
    
    # Check root password by trying to connect
    if ! docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; then
        echo "❌ Root password mismatch: .env password doesn't work with container"
        config_mismatch=true
    fi
    
    # Check if databases exist with correct names (if they exist)
    local existing_dbs=$(docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -E "^(${APIM_DB_NAME}|${SHARED_DB_NAME})$" | wc -l | tr -d ' ')
    
    if [ "$existing_dbs" -gt 0 ]; then
        # Databases exist, check names
        if ! docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '$APIM_DB_NAME';" 2>/dev/null | grep -q "$APIM_DB_NAME"; then
            local has_apim_db=$(docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -E "apim_db" | head -1)
            if [ -n "$has_apim_db" ]; then
                echo "❌ APIM database name mismatch: found '$has_apim_db', expected '$APIM_DB_NAME'"
                config_mismatch=true
            fi
        fi
        
        if ! docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES LIKE '$SHARED_DB_NAME';" 2>/dev/null | grep -q "$SHARED_DB_NAME"; then
            local has_shared_db=$(docker exec "$container_name" mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | grep -E "shared_db" | head -1)
            if [ -n "$has_shared_db" ]; then
                echo "❌ Shared database name mismatch: found '$has_shared_db', expected '$SHARED_DB_NAME'"
                config_mismatch=true
            fi
        fi
    fi
    
    if [ "$config_mismatch" = true ]; then
        echo ""
        echo "🔄 Configuration mismatch detected!"
        echo "The existing container doesn't match your .env file settings."
        echo "The container will be recreated with the correct configuration from .env file."
        echo ""
        echo "Current .env configuration:"
        echo "  MYSQL_PORT=$MYSQL_PORT"
        echo "  CONTAINER_NAME=$CONTAINER_NAME"
        echo "  MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD"
        echo "  APIM_DB_NAME=$APIM_DB_NAME"
        echo "  SHARED_DB_NAME=$SHARED_DB_NAME"
        echo "  APIM_DB_USER=$APIM_DB_USER"
        echo "  SHARED_DB_USER=$SHARED_DB_USER"
        echo ""
        
        # Stop and remove the existing container
        echo "🗑️  Removing existing container..."
        docker stop "$container_name" 2>/dev/null || true
        docker rm "$container_name" 2>/dev/null || true
        
        return 2  # Signal to create new container
    else
        echo "✅ Container configuration matches .env file"
        return 0
    fi
}

# Function to check container status
check_container_status() {
    local container_name=$1
    
    if docker ps -a --format "{{.Names}}" | grep -E "^${container_name}$" >/dev/null 2>&1; then
        local status=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "^${container_name}\s" | awk '{print $2}')
        echo "Container '$container_name' exists with status: $status"
        
        if docker ps --format "{{.Names}}" | grep -E "^${container_name}$" >/dev/null 2>&1; then
            echo "✓ Container '$container_name' is already running"
            return 0  # Container is running
        else
            echo "Container '$container_name' exists but is not running"
            return 1  # Container exists but stopped
        fi
    else
        echo "Container '$container_name' does not exist"
        return 2  # Container doesn't exist
    fi
}

# Check if required port is available
echo "Checking port availability and container status..."

# First validate container configuration against .env file
validate_container_configuration $CONTAINER_NAME
config_validation_result=$?

if [ $config_validation_result -eq 2 ]; then
    # Container was recreated, set status to create new
    container_status=2
else
    # Continue with normal checks
    check_port_availability $MYSQL_PORT $CONTAINER_NAME
    
    # Check container status (disable exit on error for this check)
    set +e
    check_container_status $CONTAINER_NAME
    container_status=$?
    set -e
fi

echo "Setting up MySQL in Docker for WSO2 API Manager..."

if [ $container_status -eq 0 ]; then
    # Container is already running
    echo "✓ MySQL container '$CONTAINER_NAME' is already running on port $MYSQL_PORT"
    echo "Skipping container creation and proceeding with database setup..."
    
elif [ $container_status -eq 1 ]; then
    # Container exists but is stopped
    echo "Starting existing MySQL container '$CONTAINER_NAME'..."
    docker start "$CONTAINER_NAME"
    
else
    # Container doesn't exist, create new one
    echo "Creating new MySQL container '$CONTAINER_NAME'..."
    # Stop and remove any existing container with the same name (cleanup)
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Start MySQL container
    echo "Starting MySQL container..."
        docker run -d \
            --name "$CONTAINER_NAME" \
            -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
            -p "$MYSQL_PORT:3306" \
            mysql:8.0 \
            --character-set-server=latin1 \
            --collation-server=latin1_swedish_ci
fi

# Wait for MySQL to be ready
echo "Waiting for MySQL to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker exec "$CONTAINER_NAME" mysqladmin ping -h"localhost" -P"3306" -uroot -p"$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; then
        echo "✓ MySQL is ready!"
        break
    fi
    
    attempt=$((attempt + 1))
    echo "Attempt $attempt/$max_attempts: Waiting for MySQL to start..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Error: MySQL failed to start within expected time"
    echo "Container logs:"
    docker logs "$CONTAINER_NAME" --tail 20
    exit 1
fi

# Run the database setup script
echo "Setting up databases..."
"$SCRIPT_DIR/setup-mysql-databases.sh"

echo "Docker MySQL setup complete!"
echo "Container: $CONTAINER_NAME"
echo "Port: $MYSQL_PORT"
echo "Root password: $MYSQL_ROOT_PASSWORD"
