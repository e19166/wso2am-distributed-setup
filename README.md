# WSO2 API Manager 4.x.0 Distributed Setup

🚀 **Complete automation for WSO2 API Manager distributed deployment with MySQL database integration**

## ⚠️ Critical Requirements

### Java Compatibility (MANDATORY)
**WSO2 API Manager 4.x.0 requires Java 11 or 17!**
- ✅ **Supported**: Java 11, Java 17
- ❌ **NOT Supported**: Java 8, Java 21, or other versions
- **Error if wrong version**: Check compatibility in docs


## 🎯 Quick Start

### ⚠️ Prerequisites First
```bash
# 1. Download, extract, and update WSO2 APIM 4.x.0 (e.g., 4.0.0, 4.1.0, 4.2.0, 4.3.0)
unzip wso2am-4.x.0.zip
# Place the extracted wso2am-4.x.0/ folder in project root
```

### 2. One-Command Complete Setup
```bash
# Setup MySQL database with Docker (includes database initialization)
./scripts/setup-mysql-docker.sh

# Alternative: Run database setup separately if needed
./scripts/setup-mysql-databases.sh

# Setup all WSO2 profiles with database integration
./scripts/setup-distributed-profiles.sh

# Update TOML files with database configuration
./scripts/update-toml-db-config.sh

# Start all profiles
./scripts/start-distributed-profiles.sh
```

### 3. Management Commands
```bash
# Check service status
./scripts/status-distributed-profiles.sh

# Stop all profiles (force kill - immediate)
./scripts/stop-distributed-profiles.sh
```

## 🗂️ Project Structure

### **Repository Structure (Clean - Before Setup):**
```
wso2am-distributed-setup/
├── README.md                           # This comprehensive guide
├── .env                               # Configuration file (tracked in Git)
├── .gitignore                          # Git ignore rules
├── docker-compose.yaml                 # Docker Compose configuration
├── conf/
│   ├── mysql-connector-j-9.2.0.jar   # MySQL connector
│   └── toml/                          # Profile-specific configurations
│       ├── cp_deployment.toml
│       ├── tm_deployment.toml
│       └── gw_deployment.toml
└── scripts/                            # Automation scripts
    ├── setup-mysql-docker.sh          # MySQL Docker setup
    ├── setup-mysql-databases.sh       # Database initialization
    ├── update-toml-db-config.sh       # TOML configuration sync
    ├── setup-distributed-profiles.sh  # Profile setup
    ├── start-distributed-profiles.sh  # Start all profiles
    └── stop-distributed-profiles.sh   # Stop all profiles
```

### **After Adding WSO2 Pack and Running Setup:**
```
wso2am-distributed-setup/
├── wso2am-4.x.0/                      # ← EXTRACTED WSO2 APIM (any 4.x.0 version)
│   ├── bin/
│   │   ├── api-manager.sh
│   │   └── profileSetup.sh
│   ├── repository/
│   ├── lib/
│   └── updates/
├── components/                         # ← Auto-created distributed profiles
│   ├── wso2am-cp/                     # Control Plane (Publisher + DevPortal + Key Manager)
│   ├── wso2am-tm/                     # Traffic Manager
│   └── wso2am-gw/                     # Gateway Worker
├── logs/                              # ← Auto-created startup logs
│   ├── startup-cp.log
│   ├── startup-tm.log
│   └── startup-gw.log
└── ...existing files...
```

## ⚙️ Configuration

### Database and Environment Configuration (`.env`)
All configuration is centralized in the root `.env` file:

```bash
# MySQL Docker Configuration
MYSQL_PORT=3326                    # Configurable MySQL port
MYSQL_ROOT_PASSWORD=my-secret      # MySQL root password
CONTAINER_NAME=wso2am-mysql        # Docker container name

# Database Configuration
APIM_DB_NAME=apim_db320           # API Manager database name
SHARED_DB_NAME=shared_db320       # Shared database name
APIM_DB_USER=apimadmin           # API Manager database user
APIM_DB_PASSWORD=apimadmin123    # API Manager database password
SHARED_DB_USER=sharedadmin       # Shared database user
SHARED_DB_PASSWORD=sharedadmin123 # Shared database password
```

**📝 Note:** The `.env` file contains default, non-sensitive values and is tracked in Git for easy setup.

### Profile Port Configuration
- **Traffic Manager**: 9711 (offset: 0)
- **Control Plane**: 9443, 9444 (offset: 0)
- **Gateway Worker**: 8284, 8247 (offset: 0)

## 🛠️ Scripts Reference

### 1. `setup-mysql-docker.sh` 🐳
**Smart MySQL Docker setup with intelligent container management**

**Features:**
- ✅ **Smart Container Detection**: Recognizes existing containers
- ✅ **Port Conflict Resolution**: Handles port conflicts intelligently
- ✅ **Database Auto-Creation**: Creates databases and users automatically
- ✅ **Schema Initialization**: Runs WSO2 SQL scripts automatically
- ✅ **Health Monitoring**: Waits for MySQL to be ready

**Usage:**
```bash
./scripts/setup-mysql-docker.sh     # Full setup
```

**Behavior:**
- **First run**: Creates new MySQL container and databases
- **Subsequent runs**: Detects existing container, skips creation
- **Port conflicts**: Distinguishes between our container vs. other processes

### 2. `update-toml-db-config.sh` 🔄
**Synchronizes `.env` database settings with all TOML configuration files**

**Features:**
- ✅ **Reads from `.env`**: Uses centralized configuration
- ✅ **Updates all TOML files**: Syncs 5 profile configurations
- ✅ **Creates backups**: Preserves original files (.bak)
- ✅ **Validates changes**: Shows updated configurations

**Usage:**
```bash
./scripts/update-toml-db-config.sh
```

**Updated Files:**
- `cp_deployment.toml` (Control Plane)
- `gw_deployment.toml` (Gateway Worker)
- `tm_deployment.toml` (Traffic Manager)

### 3. `setup-distributed-profiles.sh` 📁
**Creates distributed WSO2 profile copies with proper configurations**

**Features:**
- ✅ **Auto-Detection**: Finds WSO2AM installation or extracts from ZIP
- ✅ **Profile Creation**: Creates 3 distinct profiles
- ✅ **MySQL Connector**: Installs MySQL connector in each profile
- ✅ **TOML Configuration**: Applies profile-specific settings
- ✅ **Backup Creation**: Preserves original configurations

**Profiles Created:**
- `wso2am-cp` (Control Plane)
- `wso2am-tm` (Traffic Manager)
- `wso2am-gw` (Gateway Worker)

### 4. `start-distributed-profiles.sh` ▶️
**Starts all profiles in correct distributed deployment order**

**Features:**
- ✅ **Ordered Startup**: TM → CP → GW
- ✅ **Port Validation**: Checks port availability before starting
- ✅ **Health Monitoring**: Verifies each service starts properly
- ✅ **PID Tracking**: Creates PID files for process management
- ✅ **Logging**: Individual startup logs for each profile

**Startup Order:**
1. Traffic Manager (9711)
2. Control Plane (9443, 9444)
3. Gateway Worker (8284, 8247)

### 5. `stop-distributed-profiles.sh` ⏹️
**Force stops all profiles immediately in reverse order**

**Features:**
- ✅ **Immediate Termination**: Force kills all WSO2 processes (SIGKILL)
- ✅ **Reverse Order**: GW → CP → TM
- ✅ **Multiple Detection**: Finds processes by PID files, patterns, and port usage
- ✅ **PID Cleanup**: Removes stale PID files
- ✅ **Final Verification**: Confirms all processes are terminated

**Usage:**
```bash
./scripts/stop-distributed-profiles.sh           # Force stop (immediate)
./scripts/stop-distributed-profiles.sh --help    # Show help
```

### 6. `status-distributed-profiles.sh` 📊
**Check the status of all WSO2 API Manager profiles**

**Features:**
- ✅ **Process Status**: Shows PID and process state
- ✅ **Port Status**: Checks if services are listening on expected ports
- ✅ **Service Count**: Summary of running vs. stopped services
- ✅ **Quick URLs**: Shows service URLs when all are running

**Usage:**
```bash
./scripts/status-distributed-profiles.sh
```

### 7. `setup-mysql-databases.sh` 💾
**Direct MySQL database setup (alternative to Docker setup)**

**Features:**
- ✅ **Direct MySQL Setup**: For existing MySQL installations
- ✅ **Database Creation**: Creates APIM and Shared databases
- ✅ **User Management**: Creates database users with proper permissions
- ✅ **Schema Initialization**: Runs WSO2 SQL scripts
- ✅ **Multiple Modes**: Force, preserve, and interactive modes

**Usage:**
```bash
./scripts/setup-mysql-databases.sh          # Force recreate (default)
./scripts/setup-mysql-databases.sh --preserve   # Preserve existing data
./scripts/setup-mysql-databases.sh --interactive  # Ask before dropping
```

## 🔧 Advanced Usage

### Changing MySQL Port
```bash
# 1. Edit .env file in root directory
nano .env
# Change: MYSQL_PORT=3327

# 2. Update TOML configurations
./scripts/update-toml-db-config.sh

# 3. Recreate MySQL container
./scripts/setup-mysql-docker.sh
```


### Viewing Logs
```bash
# MySQL container logs
docker logs wso2am-mysql

# WSO2 startup logs
tail -f logs/startup-*.log

# Individual profile logs
tail -f components/wso2am-cp/repository/logs/wso2carbon.log
```

## 🔍 Troubleshooting

### Common Issues

**❌ Port Already in Use**
```bash
# Check what's using the port
lsof -i :3326

# Kill the process (if not our container)
sudo kill $(lsof -t -i:3326)

# Or change port in .env file
MYSQL_PORT=3327
```

**Credentials:**
- APIM DB: `apimadmin / apimadmin123`
- Shared DB: `sharedadmin / sharedadmin123`
- Root: `root / my-secret`

## 📋 Prerequisites

### Required Software
- **Docker**: For MySQL container management
- **Java 8 or 11 ONLY** ⚠️: For WSO2 API Manager (Java 17+ NOT supported)
- **Disk Space**: ~5GB for all profiles
- **Memory**: 8GB+ RAM recommended

### **🚨 IMPORTANT: WSO2 API Manager Pack Setup**

**Before running any scripts, you MUST prepare the WSO2 API Manager pack:**

1. **Download WSO2 API Manager 3.2.0:**

2. **Extract the pack:**
   ```bash
   unzip wso2am-3.2.0.zip
   ```

3. **Apply latest updates using WSO2 Update tool:**
   ```bash
   cd wso2am-3.2.0/bin
   ./wso2update_darwin 
   ```

4. **Place the EXTRACTED folder in the root directory:**
   ```
   wso2am-distributed-setup/
   ├── wso2am-3.2.0/             # ← EXTRACTED FOLDER HERE (updated)
   │   ├── bin/
   │   ├── repository/
   │   ├── lib/
   │   └── ...
   ├── scripts/
   ├── conf/
   └── README.md
   ```

5. **Requirements:**
   - Folder must be named exactly: `wso2am-3.2.0/`
   - Must be extracted (not ZIP file)
   - Must be updated with latest patches using wso2update tool
   - Place it in the root directory (same level as `scripts/` folder)
   - Do NOT extract it manually - scripts will handle extraction

**⚠️ The setup scripts will automatically:**
- Detect the ZIP file
- Extract it to `wso2am-3.2.0/` directory
- Create distributed profile copies in `components/` directory

### Network Ports
Ensure these ports are available:
- **3326**: MySQL (configurable)
- **9711**: Traffic Manager
- **9443-9444**: Management consoles
- **8280, 8243**: Gateway endpoints

## 🎓 Getting Started Tutorial

### Step 1: Download WSO2 API Manager Pack ⚡ **REQUIRED FIRST STEP**


### Step 2: Initial Setup
```bash
# Clone or download this setup
cd wso2am-distributed-setup

# Make scripts executable (Linux/macOS)
chmod +x scripts/*.sh
```

### Step 3: Configure Database
```bash
# Edit database settings (optional)
nano .env

# Setup MySQL with Docker
./scripts/setup-mysql-docker.sh
```

### Step 4: Setup Profiles
```bash
# Create distributed profiles (will auto-extract WSO2 pack)
./scripts/setup-distributed-profiles.sh

# Sync database configuration
./scripts/update-toml-db-config.sh
```

### Step 5: Start Services
```bash
# Start all profiles
./scripts/start-distributed-profiles.sh

# Verify services are running
curl http://localhost:8280/services/
```

### Step 6: Access Services
- **Publisher**: https://localhost:9443/publisher
- **Developer Portal**: https://localhost:9444/devportal
- **Admin Portal**: https://localhost:9443/admin
- **Gateway Worker**: http://localhost:8284, https://localhost:8247

### Step 7: Shutdown
```bash
# Graceful shutdown
./scripts/stop-distributed-profiles.sh
```
