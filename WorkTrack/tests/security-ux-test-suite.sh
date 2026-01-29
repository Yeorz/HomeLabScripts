#!/bin/bash
################################################################################
# WorkTrack Security & UX Test Suite
# Comprehensive testing for security fixes and user experience
# 
# Usage:
#   ./tests/security-ux-test-suite.sh [OPTION]
#   
# Options:
#   all              Run all tests (default)
#   security         Run security tests only
#   ux               Run UX/performance tests only
#   offline          Run offline functionality tests
#   sync             Run cross-platform sync tests
#   quick            Run quick smoke tests only
#   report           Generate HTML report
#
# Requirements:
#   - Backend running on http://localhost:3001
#   - Frontend running on http://localhost:5173 (for some tests)
#   - jq installed (for JSON parsing)
#   - curl installed
#
# Example:
#   ./tests/security-ux-test-suite.sh security
#   ./tests/security-ux-test-suite.sh all
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test timing
TEST_START_TIME=$(date +%s%N)

# Output file for report
REPORT_FILE="tests/test-report-$(date +%Y%m%d-%H%M%S).txt"
HTML_REPORT_FILE="tests/test-report-$(date +%Y%m%d-%H%M%S).html"

################################################################################
# UTILITY FUNCTIONS
################################################################################

log_test() {
  local test_num=$1
  local test_name=$2
  echo -e "${BLUE}[Test $test_num]${NC} $test_name"
}

log_pass() {
  local message=$1
  echo -e "${GREEN}✓${NC} $message"
  ((TESTS_PASSED++))
}

log_fail() {
  local message=$1
  local detail=${2:-""}
  echo -e "${RED}✗${NC} $message"
  if [ ! -z "$detail" ]; then
    echo -e "  ${RED}→${NC} $detail"
  fi
  ((TESTS_FAILED++))
}

log_skip() {
  local message=$1
  echo -e "${YELLOW}⊘${NC} $message (skipped)"
  ((TESTS_SKIPPED++))
}

log_info() {
  local message=$1
  echo -e "${CYAN}ℹ${NC} $message"
}

log_section() {
  local section=$1
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}$section${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

check_prerequisites() {
  local missing=""
  
  if ! command -v curl &> /dev/null; then
    missing="curl "
  fi
  
  if ! command -v jq &> /dev/null; then
    missing="${missing}jq "
  fi
  
  if [ ! -z "$missing" ]; then
    log_fail "Missing prerequisites: $missing"
    echo "Install with: brew install $missing"
    exit 1
  fi
  
  # Check if backend is running
  if ! curl -s http://localhost:3001/health &> /dev/null && \
     ! curl -s http://localhost:3001/auth/csrf-token &> /dev/null; then
    log_fail "Backend not running on http://localhost:3001"
    echo "Start backend with: cd backend && npm run dev"
    exit 1
  fi
  
  log_pass "Prerequisites met"
}

create_test_account() {
  local email="test-$(date +%s)@worktrack.local"
  local password="SecureTest@12345"
  
  # Register user
  curl -s -X POST http://localhost:3001/auth/register \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    > /dev/null 2>&1 || true
  
  echo "$email:$password"
}

get_auth_token() {
  local email=$1
  local password=$2
  
  curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    -c /tmp/cookies.txt 2>/dev/null | jq -r '.user.id' 2>/dev/null || echo ""
}

get_csrf_token() {
  curl -s -X GET http://localhost:3001/auth/csrf-token \
    -b /tmp/cookies.txt 2>/dev/null | jq -r '.csrfToken' 2>/dev/null || echo ""
}

################################################################################
# SECURITY TESTS (Section 1-4)
################################################################################

test_security_suite() {
  log_section "🔒 SECURITY TESTS"
  
  # Create test user
  local user_creds=$(create_test_account)
  local email=$(echo $user_creds | cut -d: -f1)
  local password=$(echo $user_creds | cut -d: -f2)
  
  # Test 1: Token stored securely (mobile)
  ((TESTS_TOTAL++))
  log_test 1 "Token storage (mobile - manual verification needed)"
  log_info "Open mobile app → Login → Check Keychain: 'com.worktrack.jwt'"
  log_skip "Manual verification required"
  
  # Test 2: Verify token NOT in response
  ((TESTS_TOTAL++))
  log_test 2 "JWT not exposed in response body"
  local login_response=$(curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    -c /tmp/cookies.txt)
  
  if echo "$login_response" | jq -e '.token' > /dev/null 2>&1; then
    log_fail "CRITICAL: Token exposed in response body"
    echo "Response: $login_response" | head -20
  else
    if echo "$login_response" | jq -e '.user' > /dev/null 2>&1; then
      log_pass "Token not exposed (only user data returned)"
    else
      log_fail "Invalid login response format"
    fi
  fi
  
  # Test 3: Verify JWT in httpOnly cookie
  ((TESTS_TOTAL++))
  log_test 3 "JWT stored in httpOnly cookie"
  local cookie_response=$(curl -s -i -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" 2>&1 | grep -i "set-cookie" || echo "")
  
  if echo "$cookie_response" | grep -iq "httponly"; then
    log_pass "JWT in httpOnly cookie (secure)"
  else
    log_fail "httpOnly flag missing from cookie" "$cookie_response"
  fi
  
  if echo "$cookie_response" | grep -iq "samesite"; then
    log_pass "SameSite cookie flag set (CSRF protection)"
  else
    log_fail "SameSite flag missing from cookie"
  fi
  
  # Test 4: Session timeout (1 hour)
  ((TESTS_TOTAL++))
  log_test 4 "Session timeout configuration (1 hour)"
  log_info "Session timeout should be 1 hour (3600 seconds)"
  log_skip "Requires 1-hour wait or backend inspection"
  
  # Test 5: CSRF token generation
  ((TESTS_TOTAL++))
  log_test 5 "CSRF token generation from backend"
  local csrf1=$(get_csrf_token)
  sleep 0.2
  local csrf2=$(get_csrf_token)
  
  if [ ! -z "$csrf1" ] && [ ! -z "$csrf2" ]; then
    if [ "$csrf1" != "$csrf2" ]; then
      log_pass "CSRF tokens generated and unique per request"
    else
      log_fail "CSRF tokens should be unique per request"
    fi
  else
    log_fail "CSRF token endpoint not working" "csrf1=$csrf1, csrf2=$csrf2"
  fi
  
  # Test 6: CSRF protection on endpoints
  ((TESTS_TOTAL++))
  log_test 6 "CSRF protection on POST endpoints"
  local csrf_token=$(get_csrf_token)
  local response=$(curl -s -X POST http://localhost:3001/workouts \
    -H "Authorization: Bearer fake-token" \
    -H "Content-Type: application/json" \
    -d '{"type":"Strength","duration":30,"calories":100}' \
    -b /tmp/cookies.txt -w "\n%{http_code}")
  
  local http_code=$(echo "$response" | tail -1)
  if [ "$http_code" == "403" ] || [ "$http_code" == "401" ]; then
    log_pass "CSRF/auth validation working (HTTP $http_code without token)"
  else
    log_fail "CSRF validation may be bypassed" "HTTP $http_code returned"
  fi
  
  # Test 7: Input validation
  ((TESTS_TOTAL++))
  log_test 7 "Input validation - calorie limits"
  local csrf_token=$(get_csrf_token)
  local response=$(curl -s -X POST http://localhost:3001/workouts \
    -H "Authorization: Bearer $csrf_token" \
    -H "X-CSRF-Token: $csrf_token" \
    -H "Content-Type: application/json" \
    -d '{"type":"Strength","duration":30,"calories":9999}' \
    -b /tmp/cookies.txt -w "\n%{http_code}")
  
  local http_code=$(echo "$response" | tail -1)
  if [ "$http_code" == "400" ]; then
    log_pass "Input validation enforced (calories > 5000 rejected)"
  elif [ "$http_code" == "401" ]; then
    log_skip "Auth required for this test"
  else
    log_fail "Input validation may not be working" "HTTP $http_code"
  fi
  
  # Test 8: XSS prevention
  ((TESTS_TOTAL++))
  log_test 8 "XSS prevention (manual web inspection needed)"
  log_info "Web frontend should use DOMPurify to sanitize HTML input"
  log_skip "Manual verification required"
}

################################################################################
# RATE LIMITING TESTS (Section 4)
################################################################################

test_rate_limiting() {
  log_section "⏱️  RATE LIMITING TESTS"
  
  # Test 11: Rate limit on auth endpoints
  ((TESTS_TOTAL++))
  log_test 11 "Rate limiting on auth endpoints (5 per 15 min)"
  
  local rate_limited=0
  local attempt_count=0
  
  for i in {1..7}; do
    ((attempt_count++))
    local response=$(curl -s -X POST http://localhost:3001/auth/login \
      -H "Content-Type: application/json" \
      -d '{"email":"nonexistent@test.com","password":"wrongpass"}' \
      -w "\n%{http_code}")
    
    local http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" == "429" ]; then
      rate_limited=1
      log_pass "Rate limit triggered after $attempt_count attempts (HTTP 429)"
      break
    fi
  done
  
  if [ $rate_limited -eq 0 ]; then
    log_fail "Rate limiting may not be active" "No 429 after $attempt_count attempts"
  fi
  
  # Test 12: Public endpoint rate limiting
  ((TESTS_TOTAL++))
  log_test 12 "Rate limiting on public endpoints (100 per 15 min)"
  log_info "Testing first 10 requests for performance..."
  
  local success_count=0
  for i in {1..10}; do
    local response=$(curl -s -X GET http://localhost:3001/public/nonexistent \
      -w "\n%{http_code}")
    local http_code=$(echo "$response" | tail -1)
    
    if [ "$http_code" == "429" ]; then
      log_fail "Rate limited too aggressively on public endpoint"
      break
    fi
    ((success_count++))
  done
  
  if [ $success_count -ge 10 ]; then
    log_pass "Public endpoint rate limiting is reasonable (10+ requests allowed)"
  fi
}

################################################################################
# PERFORMANCE & RESPONSIVENESS TESTS (Section 5)
################################################################################

test_performance() {
  log_section "⚡ PERFORMANCE & RESPONSIVENESS TESTS"
  
  local user_creds=$(create_test_account)
  local email=$(echo $user_creds | cut -d: -f1)
  local password=$(echo $user_creds | cut -d: -f2)
  
  # Test 13: Login response time
  ((TESTS_TOTAL++))
  log_test 13 "Login response time (target: <200ms)"
  
  local start_time=$(date +%s%N)
  curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    -c /tmp/cookies.txt > /dev/null
  local end_time=$(date +%s%N)
  
  local elapsed_ms=$(( (end_time - start_time) / 1000000 ))
  
  if [ $elapsed_ms -lt 200 ]; then
    log_pass "Login completed in ${elapsed_ms}ms (excellent)"
  elif [ $elapsed_ms -lt 500 ]; then
    log_pass "Login completed in ${elapsed_ms}ms (acceptable)"
  else
    log_fail "Login took ${elapsed_ms}ms (target: <200ms, acceptable: <500ms)"
  fi
  
  # Test 14: Offline queue storage (simulated)
  ((TESTS_TOTAL++))
  log_test 14 "Offline queue responsiveness"
  log_info "Mobile app should store workouts instantly to AsyncStorage"
  log_skip "Mobile-specific test - requires device/simulator"
  
  # Test 15: List workouts performance
  ((TESTS_TOTAL++))
  log_test 15 "Workout history listing performance"
  log_skip "Requires data and web UI inspection"
}

################################################################################
# OFFLINE FUNCTIONALITY TESTS (Section 6)
################################################################################

test_offline_functionality() {
  log_section "📴 OFFLINE FUNCTIONALITY TESTS"
  
  # Test 16: Offline workout logging
  ((TESTS_TOTAL++))
  log_test 16 "Offline workout logging (mobile)"
  log_info "Step 1: Disable network on mobile device"
  log_info "Step 2: Log 3 workouts in the app"
  log_info "Step 3: Verify 'pending' indicator shows"
  log_skip "Manual verification required on device"
  
  # Test 17: Auto-sync when online
  ((TESTS_TOTAL++))
  log_test 17 "Automatic sync when network restored"
  log_info "Step 1: Enable network on mobile device"
  log_info "Step 2: App should sync automatically within 5 seconds"
  log_info "Step 3: Verify workouts appear in web dashboard"
  log_skip "Manual verification required on device"
  
  # Test 18: Conflict resolution
  ((TESTS_TOTAL++))
  log_test 18 "Data conflict handling"
  log_info "Simultaneous changes from web and mobile should not cause data loss"
  log_skip "Manual testing recommended"
}

################################################################################
# CROSS-PLATFORM SYNC TESTS (Section 7)
################################################################################

test_sync_functionality() {
  log_section "🔄 CROSS-PLATFORM SYNC TESTS"
  
  # Create test account
  local user_creds=$(create_test_account)
  local email=$(echo $user_creds | cut -d: -f1)
  local password=$(echo $user_creds | cut -d: -f2)
  
  # Get auth token
  curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
    -c /tmp/cookies.txt > /dev/null
  
  # Test 19: Web-to-mobile sync
  ((TESTS_TOTAL++))
  log_test 19 "Web-to-mobile sync"
  log_info "Create workout on web dashboard"
  log_info "Mobile app should refresh within 10 seconds (or on next sync)"
  log_skip "Requires web UI and mobile interaction"
  
  # Test 20: Mobile-to-web sync
  ((TESTS_TOTAL++))
  log_test 20 "Mobile-to-web sync"
  log_info "Create workout on mobile app"
  log_info "Web dashboard should show it within 30 seconds"
  log_skip "Requires mobile device and web UI"
  
  # Test 21: Multi-device consistency
  ((TESTS_TOTAL++))
  log_test 21 "Multi-device data consistency"
  log_info "Log workouts on both web and mobile"
  log_info "Verify both platforms show identical history"
  log_skip "Requires multiple devices"
}

################################################################################
# ERROR HANDLING TESTS (Section 8)
################################################################################

test_error_handling() {
  log_section "📋 ERROR HANDLING & USER FEEDBACK TESTS"
  
  # Create test user
  local user_creds=$(create_test_account)
  local email=$(echo $user_creds | cut -d: -f1)
  local password=$(echo $user_creds | cut -d: -f2)
  
  # Test 22: Clear error messages
  ((TESTS_TOTAL++))
  log_test 22 "Clear error messages (no information leakage)"
  
  local response=$(curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"nonexistent@test.com","password":"wrongpass"}')
  
  if echo "$response" | jq -e '.error' > /dev/null 2>&1; then
    local error_msg=$(echo "$response" | jq -r '.error')
    
    if echo "$error_msg" | grep -iq "user\|email\|password"; then
      log_fail "Error message too specific" "Should say 'Invalid credentials', got: $error_msg"
    else
      log_pass "Generic error message (secure): $error_msg"
    fi
  else
    log_fail "Error response format invalid"
  fi
  
  # Test 23: Network error handling
  ((TESTS_TOTAL++))
  log_test 23 "Network error handling (manual)"
  log_info "Disable network during workout sync (mobile)"
  log_info "App should show: 'Unable to sync. Retrying...'"
  log_info "Verify no critical errors in logs"
  log_skip "Manual verification required"
  
  # Test 24: Session expiration UX
  ((TESTS_TOTAL++))
  log_test 24 "Session expiration handling"
  log_info "After 1 hour of inactivity, session should expire"
  log_info "User should see: 'Session expired. Please log in again.'"
  log_skip "Requires 1-hour wait"
}

################################################################################
# QUICK SMOKE TESTS
################################################################################

test_quick_smoke() {
  log_section "🔥 QUICK SMOKE TESTS"
  
  # Test: Backend accessible
  ((TESTS_TOTAL++))
  log_test 1 "Backend accessibility"
  if curl -s http://localhost:3001/auth/csrf-token > /dev/null 2>&1; then
    log_pass "Backend responding on :3001"
  else
    log_fail "Backend not accessible"
  fi
  
  # Test: CSRF endpoint works
  ((TESTS_TOTAL++))
  log_test 2 "CSRF token endpoint"
  local csrf=$(curl -s http://localhost:3001/auth/csrf-token | jq -r '.csrfToken' 2>/dev/null)
  if [ ! -z "$csrf" ] && [ "$csrf" != "null" ]; then
    log_pass "CSRF tokens generating correctly"
  else
    log_fail "CSRF token endpoint not working"
  fi
  
  # Test: Can create account
  ((TESTS_TOTAL++))
  log_test 3 "User registration"
  local test_email="smoke-$(date +%s)@test.com"
  local response=$(curl -s -X POST http://localhost:3001/auth/register \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$test_email\",\"password\":\"Test@12345\"}")
  
  if echo "$response" | jq -e '.user' > /dev/null 2>&1; then
    log_pass "User registration working"
  else
    log_fail "User registration endpoint error"
  fi
  
  # Test: Can login
  ((TESTS_TOTAL++))
  log_test 4 "User login"
  local response=$(curl -s -X POST http://localhost:3001/auth/login \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$test_email\",\"password\":\"Test@12345\"}")
  
  if echo "$response" | jq -e '.user' > /dev/null 2>&1; then
    log_pass "User login working"
  else
    log_fail "User login error"
  fi
}

################################################################################
# REPORTING
################################################################################

print_summary() {
  local elapsed=$(($(date +%s%N) - TEST_START_TIME))
  local elapsed_sec=$((elapsed / 1000000000))
  
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}TEST SUMMARY${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  echo -e "Total Tests:  ${CYAN}$TESTS_TOTAL${NC}"
  echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
  echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
  echo -e "Skipped:      ${YELLOW}$TESTS_SKIPPED${NC}"
  echo -e "Duration:     ${CYAN}${elapsed_sec}s${NC}"
  echo ""
  
  if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED!${NC}"
    return 0
  else
    echo -e "${RED}✗ $TESTS_FAILED TEST(S) FAILED${NC}"
    return 1
  fi
}

generate_html_report() {
  cat > "$HTML_REPORT_FILE" << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>WorkTrack Security & UX Test Report</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif; margin: 20px; background: #f5f5f5; }
    .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    h1 { color: #333; border-bottom: 3px solid #0066cc; padding-bottom: 10px; }
    .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px; margin: 20px 0; }
    .stat { padding: 15px; border-radius: 4px; text-align: center; }
    .stat-total { background: #e3f2fd; }
    .stat-passed { background: #c8e6c9; }
    .stat-failed { background: #ffcdd2; }
    .stat-skipped { background: #fff9c4; }
    .stat-value { font-size: 28px; font-weight: bold; }
    .stat-label { color: #666; font-size: 12px; margin-top: 5px; }
    .test-section { margin: 20px 0; border-left: 4px solid #0066cc; padding-left: 15px; }
    .test { margin: 10px 0; padding: 10px; background: #fafafa; border-radius: 4px; }
    .test.pass { border-left: 3px solid #4caf50; }
    .test.fail { border-left: 3px solid #f44336; background: #ffebee; }
    .test.skip { border-left: 3px solid #ff9800; background: #fff3e0; }
    .test-title { font-weight: bold; }
    .test-status { font-weight: bold; }
    .pass { color: #4caf50; }
    .fail { color: #f44336; }
    .skip { color: #ff9800; }
    .details { color: #666; font-size: 12px; margin-top: 5px; }
    footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee; text-align: center; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>🔒 WorkTrack Security & UX Test Report</h1>
    <p>Generated: <strong>{{ TIMESTAMP }}</strong></p>
    
    <div class="summary">
      <div class="stat stat-total">
        <div class="stat-value">{{ TOTAL }}</div>
        <div class="stat-label">Total Tests</div>
      </div>
      <div class="stat stat-passed">
        <div class="stat-value">{{ PASSED }}</div>
        <div class="stat-label">Passed</div>
      </div>
      <div class="stat stat-failed">
        <div class="stat-value">{{ FAILED }}</div>
        <div class="stat-label">Failed</div>
      </div>
      <div class="stat stat-skipped">
        <div class="stat-value">{{ SKIPPED }}</div>
        <div class="stat-label">Skipped</div>
      </div>
    </div>

    <h2>📋 Recommendations</h2>
    <ul>
      <li><strong>Critical:</strong> Fix any FAILED tests before deployment</li>
      <li><strong>Manual Tests:</strong> Complete all SKIPPED tests on actual devices</li>
      <li><strong>Performance:</strong> Run tests during peak usage to detect bottlenecks</li>
      <li><strong>Continuous:</strong> Re-run this suite weekly during staging phase</li>
    </ul>

    <footer>
      <p>WorkTrack Testing Suite • <a href="https://github.com/Yeorz/HomeLabScripts">View Project</a></p>
    </footer>
  </div>
</body>
</html>
EOF

  # Replace placeholders
  sed -i '' "s|{{ TIMESTAMP }}|$(date)|g" "$HTML_REPORT_FILE"
  sed -i '' "s|{{ TOTAL }}|$TESTS_TOTAL|g" "$HTML_REPORT_FILE"
  sed -i '' "s|{{ PASSED }}|$TESTS_PASSED|g" "$HTML_REPORT_FILE"
  sed -i '' "s|{{ FAILED }}|$TESTS_FAILED|g" "$HTML_REPORT_FILE"
  sed -i '' "s|{{ SKIPPED }}|$TESTS_SKIPPED|g" "$HTML_REPORT_FILE"
  
  echo ""
  echo -e "${GREEN}✓ HTML Report generated: $HTML_REPORT_FILE${NC}"
  echo "  Open with: open $HTML_REPORT_FILE"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
  local test_mode="${1:-all}"
  
  echo -e "${CYAN}"
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║     WorkTrack Security & UX Test Suite                    ║"
  echo "║     Testing environment: Local Development                ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  
  # Check prerequisites
  log_info "Checking prerequisites..."
  check_prerequisites
  echo ""
  
  # Run tests based on mode
  case "$test_mode" in
    security)
      test_security_suite
      test_rate_limiting
      test_error_handling
      ;;
    ux)
      test_performance
      test_offline_functionality
      ;;
    offline)
      test_offline_functionality
      ;;
    sync)
      test_sync_functionality
      ;;
    quick)
      test_quick_smoke
      ;;
    report)
      generate_html_report
      exit 0
      ;;
    all|*)
      test_security_suite
      test_rate_limiting
      test_performance
      test_offline_functionality
      test_sync_functionality
      test_error_handling
      ;;
  esac
  
  # Print summary
  print_summary
  local exit_code=$?
  
  # Generate report
  echo ""
  read -p "Generate HTML report? (y/n): " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    generate_html_report
  fi
  
  exit $exit_code
}

# Run main function
main "$@"
