#!/bin/bash

# Simple MySQL database setup for WSO2 API Manager
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables from .env file in root directory
if [[ -f "$BASE_DIR/.env" ]]; then
    source "$BASE_DIR/.env"
else
    echo "Warning: .env file not found in root directory. Using default values."
    MYSQL_PORT="3326"
    MYSQL_ROOT_PASSWORD="my-secret"
    APIM_DB_NAME="apim_db320"
    SHARED_DB_NAME="shared_db320"
    APIM_DB_USER="apimadmin"
    APIM_DB_PASSWORD="apimadmin123"
    SHARED_DB_USER="sharedadmin"
    SHARED_DB_PASSWORD="sharedadmin123"
fi

# Database configuration
MYSQL_HOST="127.0.0.1"

# Load container name from .env or default
if [[ -f "$BASE_DIR/.env" ]]; then
    source "$BASE_DIR/.env"
else
    CONTAINER_NAME="wso2am-mysql"
fi

echo "Setting up MySQL databases for WSO2 API Manager..."

# Create a temporary SQL file for database and user setup
TEMP_SQL_FILE=$(mktemp)
cat <<EOF > "$TEMP_SQL_FILE"
DROP DATABASE IF EXISTS $APIM_DB_NAME;
DROP DATABASE IF EXISTS $SHARED_DB_NAME;
CREATE DATABASE $APIM_DB_NAME CHARACTER SET latin1;
CREATE DATABASE $SHARED_DB_NAME CHARACTER SET latin1;

DROP USER IF EXISTS '$APIM_DB_USER'@'%';
DROP USER IF EXISTS '$SHARED_DB_USER'@'%';
CREATE USER '$APIM_DB_USER'@'%' IDENTIFIED BY '$APIM_DB_PASSWORD';
CREATE USER '$SHARED_DB_USER'@'%' IDENTIFIED BY '$SHARED_DB_PASSWORD';

GRANT ALL PRIVILEGES ON $APIM_DB_NAME.* TO '$APIM_DB_USER'@'%';
GRANT ALL PRIVILEGES ON $SHARED_DB_NAME.* TO '$SHARED_DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Execute the SQL file using docker exec
docker exec -i "$CONTAINER_NAME" mysql -h"localhost" -P"3306" -uroot -p"$MYSQL_ROOT_PASSWORD" < "$TEMP_SQL_FILE"

# Clean up temp file
rm "$TEMP_SQL_FILE"

# Find WSO2AM installation for DB scripts
SOURCE_DIR=""
for dir in "$BASE_DIR"/wso2am-*; do
    if [ -d "$dir" ] && [ -f "$dir/bin/api-manager.sh" ]; then
        SOURCE_DIR="$dir"
        break
    fi
done

if [ -n "$SOURCE_DIR" ]; then
    echo "Initializing database schemas..."
    
    # Initialize APIM database
    cat "$SOURCE_DIR/dbscripts/apimgt/mysql.sql" | docker exec -i "$CONTAINER_NAME" mysql -h"localhost" -P"3306" -u"$APIM_DB_USER" -p"$APIM_DB_PASSWORD" "$APIM_DB_NAME"
    
    # Initialize Shared database
    cat "$SOURCE_DIR/dbscripts/mysql.sql" | docker exec -i "$CONTAINER_NAME" mysql -h"localhost" -P"3306" -u"$SHARED_DB_USER" -p"$SHARED_DB_PASSWORD" "$SHARED_DB_NAME"
    
    echo "Database setup complete!"
    echo "APIM DB: $APIM_DB_NAME (user: $APIM_DB_USER)"
    echo "Shared DB: $SHARED_DB_NAME (user: $SHARED_DB_USER)"
else
    echo "Warning: WSO2AM installation not found. Databases created but not initialized."
fi
