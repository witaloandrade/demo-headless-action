#!/bin/bash
set -euo pipefail

# Smoke test: Verify EKS policy steering file contains all 6 required rules
# Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7

POLICY_FILE=".kiro/steering/eks-policy.md"
PASS_COUNT=0
FAIL_COUNT=0

# Check the policy file exists
if [ ! -f "$POLICY_FILE" ]; then
  echo "FAIL: Policy file '$POLICY_FILE' does not exist"
  exit 1
fi

echo "=== Policy Completeness Smoke Test ==="
echo "Policy file: $POLICY_FILE"
echo ""

# Define the 6 required rule names
RULES=(
  "Resource Requests and Limits"
  "Security Context"
  "Health Probes"
  "Image Tag Policy"
  "Namespace Isolation"
  "High Availability"
)

# Verify each rule exists as a distinct section heading
for rule in "${RULES[@]}"; do
  if grep -q "## Rule [0-9]*: $rule" "$POLICY_FILE"; then
    echo "PASS: Rule section found — $rule"
    ((PASS_COUNT++))
  else
    echo "FAIL: Rule section missing — $rule"
    ((FAIL_COUNT++))
  fi
done

echo ""

# Count total number of "## Rule" sections
RULE_COUNT=$(grep -c "^## Rule [0-9]*:" "$POLICY_FILE" || true)

if [ "$RULE_COUNT" -eq 6 ]; then
  echo "PASS: Exactly 6 rule sections found (count: $RULE_COUNT)"
  ((PASS_COUNT++))
else
  echo "FAIL: Expected 6 rule sections, found $RULE_COUNT"
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
echo "All policy completeness checks passed."
exit 0
