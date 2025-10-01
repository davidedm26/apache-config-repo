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

# Set correct permissions for Apache access
log "Setting correct permissions..."
# Ensure parent directories have correct permissions
sudo chmod 755 /var/www/
sudo chmod 755 "$APACHE_DOC_ROOT"
sudo chmod 755 "$APACHE_DOC_ROOT/test-files"

# Set ownership and file permissions
sudo chown -R $APACHE_USER:$APACHE_USER "$APACHE_DOC_ROOT/test-files"
sudo chmod 644 "$APACHE_DOC_ROOT/test-files"/*

# Install Apache configuration
log "Installing Apache configuration..."
sudo cp ./config/minimal.conf "$APACHE_CONFIG_DIR/"

# Fix Apache ServerName warning
log "Configuring Apache ServerName..."
echo "ServerName localhost" | sudo tee /etc/apache2/conf-available/servername.conf >/dev/null
sudo a2enconf servername

# Enable configuration and required modules
log "Enabling Apache configuration and modules..."
sudo a2enmod alias
sudo a2enmod headers
sudo a2enmod status
sudo a2enconf minimal

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
sleep 3

# Test direct file access first
log "Testing direct file access..."
for file in small medium large xlarge xxlarge; do
    if curl -s -o /dev/null -w "%{http_code}" http://localhost/test-files/$file.dat | grep -q "200"; then
        log "✓ Direct access to $file.dat working"
    else
        log "✗ Direct access to $file.dat failed"
    fi
done

# Test alias endpoints
log "Testing alias endpoints..."
failed_endpoints=()

for endpoint in small medium large xlarge xxlarge; do
    response_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/$endpoint)
    if [ "$response_code" = "200" ]; then
        log "✓ /$endpoint endpoint working (HTTP $response_code)"
    else
        log "✗ /$endpoint endpoint failed (HTTP $response_code)"
        failed_endpoints+=("$endpoint")
    fi
done

# Check if any endpoints failed
if [ ${#failed_endpoints[@]} -gt 0 ]; then
    log "Failed endpoints: ${failed_endpoints[*]}"
    log "Debug commands:"
    log "  sudo tail /var/log/apache2/error.log"
    log "  sudo apache2ctl -M | grep alias"
    log "  ls -la /var/www/html/test-files/"
    error "Some endpoints are not working properly"
else
    log "All endpoints working correctly!"
fi

log "Deployment completed successfully!"

# Configura script di monitoraggio vmstat
log ""
log "Configurando script di monitoraggio vmstat..."
chmod +x ./vmstat-monitor.sh


log ""
log "Test endpoints:"
log "  http://localhost/small   (1KB)"
log "  http://localhost/medium  (10KB)"  
log "  http://localhost/large   (100KB)"
log "  http://localhost/xlarge  (1MB)"
log "  http://localhost/xxlarge (10MB)"
log "  http://localhost/status  (server status)"
log ""
log "Monitoraggio performance:"
log "  ./vmstat-5min.sh        # Raccoglie vmstat per 5 minuti"
log "  File salvati in: /var/log/apache-performance/"
log ""
log "Ready for JMeter capacity testing!"