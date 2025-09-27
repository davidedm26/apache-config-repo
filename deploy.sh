#!/bin/bash

# Minimal Apache deployment for JMeter capacity testing
# Creates test files and configures Apache routes

set -e

log() { echo "[INFO] $1"; }
error() { echo "[ERROR] $1"; exit 1; }

# Configuration for Ubuntu 22.04 LTS
APACHE_CONFIG_DIR="/etc/apache2/conf-available"
APACHE_DOC_ROOT="/var/www/html"
APACHE_SERVICE="apache2"
APACHE_USER="www-data"

log "Deploying minimal Apache configuration for Ubuntu 22.04 LTS..."

# Create test files directory
sudo mkdir -p "$APACHE_DOC_ROOT/test-files"

# Generate test files with different sizes
log "Generating test files..."

# 1KB file
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/small.dat" bs=1024 count=1 2>/dev/null
log "Created small.dat (1KB)"

# 10KB file  
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/medium.dat" bs=1024 count=10 2>/dev/null
log "Created medium.dat (10KB)"

# 100KB file
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/large.dat" bs=1024 count=100 2>/dev/null
log "Created large.dat (100KB)"

# 1MB file
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/xlarge.dat" bs=1024 count=1024 2>/dev/null
log "Created xlarge.dat (1MB)"

# 10MB file
sudo dd if=/dev/zero of="$APACHE_DOC_ROOT/test-files/xxlarge.dat" bs=1024 count=10240 2>/dev/null
log "Created xxlarge.dat (10MB)"

# Set permissions
sudo chown -R $APACHE_USER:$APACHE_USER "$APACHE_DOC_ROOT/test-files"
sudo chmod -R 644 "$APACHE_DOC_ROOT/test-files"

# Install Apache configuration
log "Installing Apache configuration..."
sudo cp ./config/minimal.conf "$APACHE_CONFIG_DIR/"

# Enable configuration and required modules
log "Enabling Apache configuration and modules..."
sudo a2enconf minimal
sudo a2enmod headers
sudo a2enmod status

# Test configuration
if sudo apache2ctl configtest; then
    log "Apache configuration is valid"
else
    error "Apache configuration has errors"
fi

# Restart Apache
log "Restarting Apache..."
sudo systemctl restart $APACHE_SERVICE

# Verify deployment
log "Testing endpoints..."
sleep 2

for endpoint in small medium large xlarge xxlarge; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/$endpoint | grep -q "200"; then
        log "✓ /$endpoint endpoint working"
    else
        error "✗ /$endpoint endpoint failed"
    fi
done

log "Deployment completed successfully!"
log ""
log "Test endpoints:"
log "  http://localhost/small   (1KB)"
log "  http://localhost/medium  (10KB)"  
log "  http://localhost/large   (100KB)"
log "  http://localhost/xlarge  (1MB)"
log "  http://localhost/xxlarge (10MB)"
log "  http://localhost/status  (server status)"
log ""
log "Ready for JMeter capacity testing!"