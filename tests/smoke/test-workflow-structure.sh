#!/bin/bash
set -euo pipefail

# Smoke test: Verify GitHub Actions workflow structure
# Validates: Requirements 3.1, 3.4, 3.6, 7.1, 7.2

WORKFLOW_FILE=".github/workflows/kiro-policy-gate.yml"
PASS=0
FAIL=0

# Navigate to repo root
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo "$(dirname "$0")/../..")"

echo "=== Workflow Structure Smoke Test ==="
echo "File: ${WORKFLOW_FILE}"
echo ""

# Check file exists
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FAIL: Workflow file does not exist: ${WORKFLOW_FILE}"
  exit 1
fi

# Check 1: pull_request trigger with 'opened' type
if grep -q 'pull_request' "$WORKFLOW_FILE" && grep -q 'opened' "$WORKFLOW_FILE"; then
  echo "PASS: pull_request trigger with 'opened' type found"
  PASS=$((PASS + 1))
else
  echo "FAIL: pull_request trigger with 'opened' type not found"
  FAIL=$((FAIL + 1))
fi

# Check 2: pull_request trigger with 'synchronize' type
if grep -q 'synchronize' "$WORKFLOW_FILE"; then
  echo "PASS: pull_request trigger with 'synchronize' type found"
  PASS=$((PASS + 1))
else
  echo "FAIL: pull_request trigger with 'synchronize' type not found"
  FAIL=$((FAIL + 1))
fi

# Check 3: validate job has timeout-minutes: 5
if grep -q 'timeout-minutes: 5' "$WORKFLOW_FILE"; then
  echo "PASS: validate job has timeout-minutes: 5"
  PASS=$((PASS + 1))
else
  echo "FAIL: timeout-minutes: 5 not found in workflow"
  FAIL=$((FAIL + 1))
fi

# Check 4: deploy job has needs referencing validate
if grep -qE 'needs:.*validate' "$WORKFLOW_FILE"; then
  echo "PASS: deploy job has needs referencing validate"
  PASS=$((PASS + 1))
else
  echo "FAIL: deploy job does not have needs referencing validate"
  FAIL=$((FAIL + 1))
fi

# Check 5: kubectl apply command present
if grep -q 'kubectl apply' "$WORKFLOW_FILE"; then
  echo "PASS: kubectl apply command found"
  PASS=$((PASS + 1))
else
  echo "FAIL: kubectl apply command not found"
  FAIL=$((FAIL + 1))
fi

# Check 6: kubectl wait with --timeout=120s present
if grep -q 'kubectl wait' "$WORKFLOW_FILE" && grep -q '\-\-timeout=120s' "$WORKFLOW_FILE"; then
  echo "PASS: kubectl wait with --timeout=120s found"
  PASS=$((PASS + 1))
else
  echo "FAIL: kubectl wait with --timeout=120s not found"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
