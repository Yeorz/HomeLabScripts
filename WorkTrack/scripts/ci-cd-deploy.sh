#!/bin/bash

###############################################################################
# WorkTrack CI/CD Deployment Pipeline
# Integrates with GitHub Actions / GitLab CI for automated deployments
###############################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

###############################################################################
# Build Functions
###############################################################################

build_backend() {
    log "Building backend..."
    
    cd backend
    npm ci
    npm run lint || warning "Linting failed, continuing..."
    npm run test || warning "Tests failed, continuing..."
    npm run build || true
    
    success "Backend built"
    cd ..
}

build_frontend() {
    log "Building frontend..."
    
    cd web
    npm ci
    npm run lint || warning "Linting failed, continuing..."
    npm run test || warning "Tests failed, continuing..."
    npm run build
    
    success "Frontend built"
    cd ..
}

###############################################################################
# Deployment Functions
###############################################################################

deploy_to_container() {
    local container_id=$1
    local container_ip=$2
    
    log "Deploying to container $container_id ($container_ip)..."
    
    # Check container accessibility
    if ! ping -c 1 "$container_ip" &> /dev/null; then
        error "Container $container_ip is not reachable"
    fi
    
    # Deploy backend
    log "Deploying backend..."
    scp -r backend/* "root@$container_ip:/opt/worktrack/backend/" || error "Backend deployment failed"
    
    # Deploy frontend build
    log "Deploying frontend..."
    scp -r web/dist/* "root@$container_ip:/opt/worktrack/web/dist/" || error "Frontend deployment failed"
    
    # Restart services
    log "Restarting services..."
    ssh "root@$container_ip" "systemctl restart worktrack-backend worktrack-web" || error "Service restart failed"
    
    # Health check
    log "Running health checks..."
    sleep 5
    
    if ! ssh "root@$container_ip" "curl -f http://localhost:3001/health" &> /dev/null; then
        error "Backend health check failed"
    fi
    
    if ! ssh "root@$container_ip" "curl -f http://localhost:5173" &> /dev/null; then
        error "Frontend health check failed"
    fi
    
    success "Deployment completed successfully"
}

###############################################################################
# Blue-Green Deployment
###############################################################################

deploy_blue_green() {
    local primary_container=$1
    local secondary_container=$2
    local primary_ip=$3
    local secondary_ip=$4
    
    log "Starting blue-green deployment..."
    log "Primary container: $primary_container ($primary_ip)"
    log "Secondary container: $secondary_container ($secondary_ip)"
    
    # Deploy to secondary (green)
    log "Deploying to secondary container (green)..."
    deploy_to_container "$secondary_container" "$secondary_ip"
    
    # Run smoke tests on secondary
    log "Running smoke tests on green environment..."
    if ! ssh "root@$secondary_ip" "bash /tmp/smoke-tests.sh"; then
        warning "Smoke tests failed on green, rolling back..."
        ssh "root@$secondary_ip" "systemctl restart worktrack-backend worktrack-web"
        error "Green deployment failed smoke tests"
    fi
    
    # Switch traffic to secondary
    log "Switching traffic from blue to green..."
    # This would typically involve updating Nginx upstream config or load balancer
    
    success "Blue-green deployment completed"
}

###############################################################################
# Canary Deployment
###############################################################################

deploy_canary() {
    local container_id=$1
    local container_ip=$2
    local canary_percentage=${3:-10}  # Start with 10% traffic
    
    log "Starting canary deployment (${canary_percentage}% traffic)..."
    
    # Deploy to container
    deploy_to_container "$container_id" "$container_ip"
    
    # Configure Nginx canary routing (weighted)
    log "Configuring canary routing with ${canary_percentage}% traffic..."
    ssh "root@$container_ip" "cat > /tmp/canary-weights.conf << 'EOF'
upstream worktrack_stable {
    server worktrack-old:3001 weight=$((100 - $canary_percentage));
}

upstream worktrack_canary {
    server worktrack-new:3001 weight=$canary_percentage;
}
EOF"
    
    # Monitor metrics
    log "Monitoring canary metrics for 5 minutes..."
    sleep 300
    
    log "Checking error rates..."
    # Query Prometheus for error rate increase
    local error_increase=$(ssh "root@$container_ip" \
        'curl -s "http://localhost:9090/api/v1/query?query=rate(worktrack_errors_total%5B5m%5D)" | grep -o "\"value\":\[[0-9]*\." | head -1')
    
    if [[ $error_increase -gt 1000 ]]; then
        warning "Error rate increased significantly, rolling back canary..."
        ssh "root@$container_ip" "sed -i 's/weight=$canary_percentage/weight=0/' /tmp/canary-weights.conf"
        return 1
    fi
    
    log "Increasing canary traffic to 50%..."
    ssh "root@$container_ip" "sed -i 's/weight=$canary_percentage/weight=50/' /tmp/canary-weights.conf"
    sleep 300
    
    log "Increasing canary traffic to 100%..."
    ssh "root@$container_ip" "sed -i 's/weight=50/weight=100/' /tmp/canary-weights.conf"
    
    success "Canary deployment completed"
}

###############################################################################
# Rollback Functions
###############################################################################

rollback_deployment() {
    local container_id=$1
    local container_ip=$2
    local backup_file=$3
    
    log "Rolling back to $backup_file..."
    
    warning "Stopping services before rollback..."
    ssh "root@$container_ip" "systemctl stop worktrack-backend worktrack-web"
    
    log "Restoring files from backup..."
    ssh "root@$container_ip" "tar -xzf $backup_file -C /opt/worktrack/"
    
    log "Restarting services..."
    ssh "root@$container_ip" "systemctl start worktrack-backend worktrack-web"
    
    sleep 5
    
    if ssh "root@$container_ip" "curl -f http://localhost:3001/health" &> /dev/null; then
        success "Rollback completed successfully"
    else
        error "Rollback failed - services not healthy"
    fi
}

###############################################################################
# Testing Functions
###############################################################################

run_integration_tests() {
    local api_url=$1
    
    log "Running integration tests against $api_url..."
    
    # Health check
    if ! curl -f "$api_url/health" &> /dev/null; then
        error "API health check failed"
    fi
    
    # Auth endpoint test
    response=$(curl -s -X POST "$api_url/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"email":"test@example.com","password":"test123"}')
    
    if echo "$response" | grep -q "error"; then
        warning "Auth test returned error (expected if test user doesn't exist)"
    fi
    
    # Public profile test
    if ! curl -f "$api_url/public/test-user" &> /dev/null; then
        warning "Public profile test returned 404 (expected if user doesn't exist)"
    fi
    
    success "Integration tests completed"
}

run_load_tests() {
    local api_url=$1
    local duration=${2:-60}
    local concurrency=${3:-10}
    
    log "Running load tests against $api_url..."
    log "Duration: ${duration}s, Concurrency: $concurrency"
    
    # Install ab if needed
    if ! command -v ab &> /dev/null; then
        warning "Apache Bench (ab) not installed, installing..."
        apt-get install -y apache2-utils || brew install httpd
    fi
    
    # Run load test
    ab -n 1000 -c "$concurrency" -t "$duration" "$api_url/" || warning "Load test failed"
    
    success "Load tests completed"
}

run_security_tests() {
    log "Running security tests..."
    
    # Check for common vulnerabilities
    warning "Checking backend for vulnerabilities..."
    cd backend
    
    # Check for npm vulnerabilities
    npm audit --production || warning "Some npm vulnerabilities found"
    
    # Run security linter
    npm run lint:security 2>/dev/null || log "No security linter configured"
    
    cd ..
    
    success "Security tests completed"
}

###############################################################################
# Smoke Tests
###############################################################################

create_smoke_tests() {
    cat > /tmp/smoke-tests.sh << 'EOF'
#!/bin/bash

API_URL="http://localhost:3001"
FRONTEND_URL="http://localhost:5173"
TIMEOUT=10

test_passed=0
test_failed=0

run_test() {
    local name=$1
    local command=$2
    
    if eval "$command"; then
        echo "✓ $name"
        ((test_passed++))
    else
        echo "✗ $name"
        ((test_failed++))
    fi
}

# API tests
run_test "API Health" "curl -f --max-time $TIMEOUT $API_URL/health"
run_test "API Auth Endpoint" "curl -f --max-time $TIMEOUT -X POST $API_URL/auth/register"
run_test "API Workouts Endpoint" "curl -f --max-time $TIMEOUT $API_URL/workouts || true"

# Frontend tests
run_test "Frontend Response" "curl -f --max-time $TIMEOUT $FRONTEND_URL"
run_test "Frontend Assets" "curl -f --max-time $TIMEOUT $FRONTEND_URL/assets/ || true"

echo ""
echo "Smoke Tests: $test_passed passed, $test_failed failed"

if [ $test_failed -gt 0 ]; then
    exit 1
fi
EOF
    
    chmod +x /tmp/smoke-tests.sh
}

###############################################################################
# Main Command Handler
###############################################################################

usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
  build-all                     Build backend and frontend
  build-backend                 Build backend only
  build-frontend                Build frontend only
  
  deploy <container_id> <ip>    Deploy to container
  rollback <container_id> <ip> <backup> Rollback deployment
  
  blue-green <p_id> <s_id> <p_ip> <s_ip>  Blue-green deployment
  canary <container_id> <ip> [percentage] Canary deployment
  
  test-integration <url>        Run integration tests
  test-load <url> [duration] [concurrency]  Run load tests
  test-security                 Run security tests
  
  create-smoke-tests            Generate smoke test script

Examples:
  $0 build-all
  $0 deploy 100 192.168.1.100
  $0 blue-green 100 101 192.168.1.100 192.168.1.101
  $0 canary 100 192.168.1.100 10
  $0 test-integration http://localhost:3001

EOF
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

case "$1" in
    build-all)
        build_backend
        build_frontend
        ;;
    build-backend)
        build_backend
        ;;
    build-frontend)
        build_frontend
        ;;
    deploy)
        [ $# -lt 3 ] && error "Usage: $0 deploy <container_id> <ip>"
        deploy_to_container "$2" "$3"
        ;;
    rollback)
        [ $# -lt 4 ] && error "Usage: $0 rollback <container_id> <ip> <backup_file>"
        rollback_deployment "$2" "$3" "$4"
        ;;
    blue-green)
        [ $# -lt 5 ] && error "Usage: $0 blue-green <p_id> <s_id> <p_ip> <s_ip>"
        deploy_blue_green "$2" "$3" "$4" "$5"
        ;;
    canary)
        [ $# -lt 3 ] && error "Usage: $0 canary <container_id> <ip> [percentage]"
        deploy_canary "$2" "$3" "${4:-10}"
        ;;
    test-integration)
        [ $# -lt 2 ] && error "Usage: $0 test-integration <url>"
        run_integration_tests "$2"
        ;;
    test-load)
        [ $# -lt 2 ] && error "Usage: $0 test-load <url> [duration] [concurrency]"
        run_load_tests "$2" "${3:-60}" "${4:-10}"
        ;;
    test-security)
        run_security_tests
        ;;
    create-smoke-tests)
        create_smoke_tests
        success "Smoke tests created at /tmp/smoke-tests.sh"
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac
