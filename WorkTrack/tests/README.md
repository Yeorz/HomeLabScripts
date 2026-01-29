# WorkTrack Security & UX Test Suite

Comprehensive automated test suite for security and user experience validation.

## Quick Start

```bash
# Run all tests
./tests/security-ux-test-suite.sh all

# Run specific test suites
./tests/security-ux-test-suite.sh security      # Security tests only
./tests/security-ux-test-suite.sh ux            # Performance/UX tests
./tests/security-ux-test-suite.sh offline       # Offline functionality
./tests/security-ux-test-suite.sh sync          # Cross-platform sync
./tests/security-ux-test-suite.sh quick         # Quick smoke tests
./tests/security-ux-test-suite.sh report        # Generate HTML report
```

## Requirements

- **Backend running** on `http://localhost:3001`
- **curl** installed
- **jq** installed (JSON parser)

### Installation

```bash
# macOS
brew install curl jq

# Ubuntu/Debian
sudo apt-get install curl jq

# Fedora
sudo dnf install curl jq
```

## Test Coverage

### 🔒 Security Tests (8 tests)
- **Test 1**: Token storage verification (mobile - manual)
- **Test 2**: JWT not exposed in response body
- **Test 3**: JWT in httpOnly cookie (secure flag)
- **Test 4**: Session timeout (1 hour)
- **Test 5**: CSRF token generation
- **Test 6**: CSRF protection on POST endpoints
- **Test 7**: Input validation (calorie limits)
- **Test 8**: XSS prevention (manual)

### ⏱️ Rate Limiting Tests (2 tests)
- **Test 11**: Auth endpoint rate limiting (5 per 15 min)
- **Test 12**: Public endpoint rate limiting (100 per 15 min)

### ⚡ Performance Tests (3 tests)
- **Test 13**: Login response time (<200ms target)
- **Test 14**: Offline queue responsiveness
- **Test 15**: Workout history listing performance

### 📴 Offline Tests (3 tests)
- **Test 16**: Offline workout logging
- **Test 17**: Auto-sync when online
- **Test 18**: Conflict resolution

### 🔄 Sync Tests (3 tests)
- **Test 19**: Web-to-mobile sync
- **Test 20**: Mobile-to-web sync
- **Test 21**: Multi-device consistency

### 📋 Error Handling Tests (3 tests)
- **Test 22**: Clear error messages (no info leakage)
- **Test 23**: Network error handling
- **Test 24**: Session expiration UX

## Test Results Interpretation

### ✓ Green (Passed)
- Automated test verified the security/UX requirement
- No action needed

### ✗ Red (Failed)
- **CRITICAL**: Test detected a security vulnerability or broken functionality
- Must be fixed before deployment
- Check the error message for details

### ⊘ Yellow (Skipped)
- Requires manual verification on device/browser
- Not automatically testable
- Completion needed before production deployment

## Manual Test Checklist

For **skipped tests**, complete these manually:

- [ ] **Token Storage (mobile)**: Open Keychain utility, verify JWT stored encrypted
- [ ] **Token Not Exposed**: Check network tab in DevTools, confirm token not in response
- [ ] **Session Timeout**: Wait 1+ hour, verify auto-logout occurs
- [ ] **XSS Prevention**: Inject `<script>alert('xss')</script>`, verify rendered as text
- [ ] **Offline Logging**: Disable network, log 3 workouts, verify sync when online
- [ ] **Auto-sync**: Enable network, verify workouts sync within 5 seconds
- [ ] **Web-to-Mobile**: Create workout on web, check mobile within 10 seconds
- [ ] **Mobile-to-Web**: Create on mobile, check web dashboard within 30 seconds
- [ ] **Session Expiration**: Let session expire (1 hour), verify smooth redirect + message

## Performance Benchmarks

| Metric | Target | Acceptable | Flag If |
|--------|--------|-----------|---------|
| Login time | <200ms | <500ms | >500ms |
| Offline store | <50ms | <100ms | >100ms |
| Sync initiation | <2s | <5s | >5s |
| Workout list | <1s | <3s | >3s |
| Auto-sync | <10s | <30s | >30s |

## Interpreting HTML Report

```
Tests Run: 24
✓ Passed:  20
✗ Failed:  2
⊘ Skipped: 2
```

**Decision**:
- **0 Failed**: ✅ Ready for deployment
- **1-3 Failed**: ⚠️ Review failures, fix if critical
- **4+ Failed**: ❌ Do not deploy, fix issues first

## Common Issues & Solutions

### Backend Not Running
```
Error: Backend not accessible on http://localhost:3001
Solution: cd backend && npm run dev
```

### CSRF Token Returns null
```
Error: CSRF token endpoint returns null
Solution: Verify server.js has csurf middleware configured
```

### Rate Limiting Not Triggered
```
Error: Still getting successful responses after 5+ attempts
Solution: Check that express-rate-limit is properly installed
```

### Skipped Tests Block Deployment
- Manual testing is **required before production**
- Use the checklist above to verify all manual tests
- Create a manual test log document

## Testing Schedule

| Phase | Frequency | Coverage |
|-------|-----------|----------|
| **Development** | After each security change | Security tests only |
| **Pre-staging** | Before deploying | All automated + critical manual |
| **Staging** | Weekly | Full suite |
| **Before Prod** | 1 week before | All tests |
| **Post-deployment** | Daily (1 week) | Smoke tests (#quick) |
| **Production** | Monthly | Smoke tests + spot checks |

## Continuous Integration

Add to GitHub Actions workflow:

```yaml
- name: Run security tests
  run: ./tests/security-ux-test-suite.sh quick
  if: always()

- name: Upload test report
  uses: actions/upload-artifact@v2
  if: always()
  with:
    name: test-reports
    path: tests/test-report-*.html
```

## Troubleshooting

### Test Hangs on Specific Test
- Press `Ctrl+C` to stop
- Check backend is running: `curl http://localhost:3001/health`
- Review test output for details
- Try running that specific test in isolation

### All Tests Skipped
- Verify prerequisites: `which curl` and `which jq`
- Check backend on correct port: `curl http://localhost:3001/auth/csrf-token`

### Rate Limit Tests Fail
- Clear browser cookies: `rm -f /tmp/cookies.txt`
- Wait a few minutes for rate limit window to reset
- Run again

## Contributing

To add new tests:
1. Create test function: `test_my_feature()`
2. Add call in `main()` function
3. Follow naming convention: `log_test N "Description"`
4. Return pass/fail via `log_pass`/`log_fail`
5. Update this README

## Files

```
tests/
├── security-ux-test-suite.sh    ← Main test runner (executable)
├── README.md                     ← This file
└── test-report-YYYYMMDD-HHMMSS.html  ← Generated reports
```

## Support

For issues or questions:
- Check test output messages for details
- Review the [Security Audit Report](../SECURITY_AUDIT_REPORT.md)
- Consult [Security Remediation Guide](../SECURITY_REMEDIATION_GUIDE.md)
- Check backend logs: `cd backend && npm run dev`

---

**Last Updated**: January 2026  
**Maintained by**: Security & QA Team  
**Status**: Production Ready ✅
