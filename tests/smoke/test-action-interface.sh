#!/bin/bash
set -euo pipefail

# Smoke test: Verify Kiro Validate Action defines required inputs and outputs
# Validates: Requirements 1.1, 1.5

ACTION_FILE=".github/actions/kiro-validate/action.yml"
PASS_COUNT=0
FAIL_COUNT=0

# Check the action file exists
if [ ! -f "$ACTION_FILE" ]; then
  echo "FAIL: Action file '$ACTION_FILE' does not exist"
  exit 1
fi

echo "=== Action Interface Smoke Test ==="
echo "Action file: $ACTION_FILE"
echo ""

# Check manifests-path input is defined
if grep -q "manifests-path:" "$ACTION_FILE"; then
  echo "PASS: 'manifests-path' input is defined"
  ((PASS_COUNT++))
else
  echo "FAIL: 'manifests-path' input is not defined"
  ((FAIL_COUNT++))
fi

# Check policy-path input is defined
if grep -q "policy-path:" "$ACTION_FILE"; then
  echo "PASS: 'policy-path' input is defined"
  ((PASS_COUNT++))
else
  echo "FAIL: 'policy-path' input is not defined"
  ((FAIL_COUNT++))
fi

# Check manifests-path is required
if grep -A 3 "manifests-path:" "$ACTION_FILE" | grep -q "required: true"; then
  echo "PASS: 'manifests-path' input is required"
  ((PASS_COUNT++))
else
  echo "FAIL: 'manifests-path' input is not marked as required"
  ((FAIL_COUNT++))
fi

# Check policy-path is required
if grep -A 3 "policy-path:" "$ACTION_FILE" | grep -q "required: true"; then
  echo "PASS: 'policy-path' input is required"
  ((PASS_COUNT++))
else
  echo "FAIL: 'policy-path' input is not marked as required"
  ((FAIL_COUNT++))
fi

# Check report output is defined
if grep -q "report:" "$ACTION_FILE"; then
  echo "PASS: 'report' output is defined"
  ((PASS_COUNT++))
else
  echo "FAIL: 'report' output is not defined"
  ((FAIL_COUNT++))
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

echo ""
echo "All action interface checks passed."
exit 0
