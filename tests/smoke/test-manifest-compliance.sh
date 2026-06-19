#!/bin/bash
set -euo pipefail

# Manifest Compliance Smoke Test
# Validates that the compliant manifest satisfies all policy rules
# and the non-compliant manifest intentionally violates them.
# Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMPLIANT="$REPO_ROOT/manifests/compliant/deployment.yaml"
NON_COMPLIANT="$REPO_ROOT/manifests/non-compliant/deployment.yaml"

PASS=0
FAIL=0

check() {
  local description="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo "PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $description"
    FAIL=$((FAIL + 1))
  fi
}

# Verify manifest files exist
if [ ! -f "$COMPLIANT" ]; then
  echo "ERROR: Compliant manifest not found at $COMPLIANT"
  exit 1
fi

if [ ! -f "$NON_COMPLIANT" ]; then
  echo "ERROR: Non-compliant manifest not found at $NON_COMPLIANT"
  exit 1
fi

echo "=== Compliant Manifest Checks ==="

# Req 4.1: Explicit non-default namespace
grep -q "namespace:" "$COMPLIANT" && ! grep -q "namespace: default" "$COMPLIANT"
check "Compliant: has explicit non-default namespace" $?

# Req 4.2: Replicas >= 2
REPLICAS=$(grep "replicas:" "$COMPLIANT" | head -1 | awk '{print $2}')
[ "$REPLICAS" -ge 2 ] 2>/dev/null
check "Compliant: replicas >= 2" $?

# Req 4.3: Resource requests and limits present
grep -q "resources:" "$COMPLIANT"
check "Compliant: has resources section" $?

grep -q "requests:" "$COMPLIANT"
check "Compliant: has requests" $?

grep -q "limits:" "$COMPLIANT"
check "Compliant: has limits" $?

grep -q "cpu:" "$COMPLIANT"
check "Compliant: has cpu defined" $?

grep -q "memory:" "$COMPLIANT"
check "Compliant: has memory defined" $?

# Req 4.4: Security context fields
grep -q "securityContext:" "$COMPLIANT"
check "Compliant: has securityContext" $?

grep -q "runAsNonRoot: true" "$COMPLIANT"
check "Compliant: runAsNonRoot is true" $?

grep -q "readOnlyRootFilesystem: true" "$COMPLIANT"
check "Compliant: readOnlyRootFilesystem is true" $?

grep -q 'drop:' "$COMPLIANT" && grep -q 'ALL' "$COMPLIANT"
check "Compliant: drops ALL capabilities" $?

# Req 4.5: Probes present
grep -q "livenessProbe:" "$COMPLIANT"
check "Compliant: has livenessProbe" $?

grep -q "readinessProbe:" "$COMPLIANT"
check "Compliant: has readinessProbe" $?

# Req 4.6: Pinned image tag (not latest)
grep -q "image:" "$COMPLIANT" && ! grep -q "image:.*latest" "$COMPLIANT"
check "Compliant: image tag is pinned (not latest)" $?

echo ""
echo "=== Non-Compliant Manifest Checks ==="

# Req 5.1: Missing namespace
! grep -q "^  namespace:" "$NON_COMPLIANT"
check "Non-compliant: missing namespace field" $?

# Req 5.2: Replicas < 2
grep -q "replicas: 1" "$NON_COMPLIANT"
check "Non-compliant: replicas is 1" $?

# Req 5.3: Missing resources
! grep -q "resources:" "$NON_COMPLIANT"
check "Non-compliant: missing resources section" $?

# Req 5.4: Missing securityContext
! grep -q "securityContext:" "$NON_COMPLIANT"
check "Non-compliant: missing securityContext" $?

# Req 5.5: Missing probes
! grep -q "livenessProbe:" "$NON_COMPLIANT"
check "Non-compliant: missing livenessProbe" $?

! grep -q "readinessProbe:" "$NON_COMPLIANT"
check "Non-compliant: missing readinessProbe" $?

# Req 5.6: Uses latest tag
grep -q "nginx:latest" "$NON_COMPLIANT"
check "Non-compliant: uses nginx:latest" $?

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo "All manifest compliance checks passed."
exit 0
