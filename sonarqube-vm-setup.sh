#!/bin/bash

# Complete SonarQube VM Setup Script
# This script installs Docker and deploys SonarQube on a fresh VM

set -e

echo "================================================"
echo "SonarQube VM Complete Setup"
echo "================================================"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo" 
   exit 1
fi

# ========================================
# STEP 1: Install Docker
# ========================================
echo "Step 1: Installing Docker..."
echo "================================================"

# Check if Docker is already installed
if command -v docker &> /dev/null; then
    echo "Docker is already installed"
    docker --version
else
    echo "Installing Docker..."
    
    # Install dependencies
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    echo "✅ Docker installed successfully"
    docker --version
fi

echo ""

# ========================================
# STEP 2: Configure System for SonarQube
# ========================================
echo "Step 2: Configuring system parameters..."
echo "================================================"

# Set kernel parameters for Elasticsearch (required by SonarQube)
sysctl -w vm.max_map_count=524288
sysctl -w fs.file-max=131072

# Make changes persistent
if ! grep -q "vm.max_map_count" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << EOF

# SonarQube requirements
vm.max_map_count=524288
fs.file-max=131072
EOF
fi

# Set ulimits
cat > /etc/security/limits.d/99-sonarqube.conf << EOF
*   soft    nofile  131072
*   hard    nofile  131072
*   soft    nproc   8192
*   hard    nproc   8192
EOF

echo "✅ System configured for SonarQube"
echo ""

# ========================================
# STEP 3: Pull SonarQube Images
# ========================================
echo "Step 3: Pulling SonarQube Docker images..."
echo "================================================"

docker pull sonarqube:lts-community
docker pull postgres:13-alpine

echo "✅ Images pulled successfully"
echo ""

# ========================================
# STEP 4: Create SonarQube Directory
# ========================================
echo "Step 4: Creating SonarQube directories..."
echo "================================================"

SONAR_DIR="/opt/sonarqube"
mkdir -p $SONAR_DIR/{data,extensions,logs,conf,postgres-data}

# Set ownership (UID 1000 is the sonarqube user in the container)
chown -R 1000:1000 $SONAR_DIR/{data,extensions,logs,conf}

echo "✅ Directories created at $SONAR_DIR"
echo ""

# ========================================
# STEP 5: Create Docker Network
# ========================================
echo "Step 5: Creating Docker network..."
echo "================================================"

docker network create sonarnet 2>/dev/null || echo "Network already exists"

echo "✅ Docker network created"
echo ""

# ========================================
# STEP 6: Start PostgreSQL Database
# ========================================
echo "Step 6: Starting PostgreSQL database..."
echo "================================================"

docker run -d \
  --name sonarqube-db \
  --network sonarnet \
  -e POSTGRES_USER=sonar \
  -e POSTGRES_PASSWORD=sonar \
  -e POSTGRES_DB=sonar \
  -v $SONAR_DIR/postgres-data:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:13-alpine

echo "✅ PostgreSQL started"
echo "Waiting for database to be ready..."
sleep 10
echo ""

# ========================================
# STEP 7: Start SonarQube
# ========================================
echo "Step 7: Starting SonarQube..."
echo "================================================"

docker run -d \
  --name sonarqube \
  --network sonarnet \
  -p 9000:9000 \
  -e SONAR_JDBC_URL=jdbc:postgresql://sonarqube-db:5432/sonar \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -v $SONAR_DIR/data:/opt/sonarqube/data \
  -v $SONAR_DIR/extensions:/opt/sonarqube/extensions \
  -v $SONAR_DIR/logs:/opt/sonarqube/logs \
  -v $SONAR_DIR/conf:/opt/sonarqube/conf \
  --ulimit nofile=131072:131072 \
  --ulimit nproc=8192:8192 \
  --restart unless-stopped \
  sonarqube:lts-community

echo "✅ SonarQube container started"

echo ""
echo "Waiting for SonarQube to start (this may take 2-3 minutes)..."
echo "This is normal - SonarQube needs time to initialize..."
echo ""

# Wait for SonarQube to be ready
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:9000/api/system/health | grep -q "GREEN\|YELLOW"; then
        echo ""
        echo "✅ SonarQube is up and running!"
        break
    fi
    echo -n "."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo ""
    echo "⚠️  Timeout waiting for SonarQube. Check logs with: docker logs sonarqube"
    echo "SonarQube may still be starting up. Give it a few more minutes."
fi

echo ""
echo "================================================"
echo "✅ SonarQube Deployment Complete!"
echo "================================================"
echo ""
echo "📋 Connection Details:"
echo "  URL: http://$(hostname -I | awk '{print $1}'):9000"
echo "  Default Username: admin"
echo "  Default Password: admin"
echo ""
echo "⚠️  IMPORTANT: Change the default password on first login!"
echo ""
echo "📌 Useful Commands:"
echo "  View logs:      docker logs -f sonarqube"
echo "  Stop:           docker stop sonarqube sonarqube-db"
echo "  Start:          docker start sonarqube-db sonarqube"
echo "  Restart:        docker restart sonarqube"
echo "  Status:         docker ps"
echo "  Remove:         docker rm -f sonarqube sonarqube-db"
echo ""
echo "� Next Steps:"
echo "  1. Access SonarQube at http://$(hostname -I | awk '{print $1}'):9000"
echo "  2. Login with admin/admin"
echo "  3. Change the default password"
echo "  4. Create a new project"
echo "  5. Generate an authentication token for GitLab CI/CD"
echo ""
echo "📚 Installation Directory: $SONAR_DIR"
echo ""
