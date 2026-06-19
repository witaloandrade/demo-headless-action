# Implementation Plan: Kiro EKS Policy Gate

## Overview

This plan implements a demo CI/CD pipeline that uses Kiro headless as an AI-powered policy gate for EKS deployments. The implementation proceeds bottom-up: policy definition → sample manifests → composite action → workflow → smoke tests. Each task builds on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Create EKS policy steering file and sample manifests
  - [x] 1.1 Create the EKS best practices policy steering file
    - Create `.kiro/steering/eks-policy.md` with 6 distinct rule sections
    - Each rule section must include: rule name/identifier, description, what to check, compliant vs non-compliant examples
    - Rules: Resource Requests and Limits, Security Context, Health Probes, Image Tag Policy, Namespace Isolation, High Availability
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 1.2 Create the compliant nginx deployment manifest
    - Create `manifests/compliant/deployment.yaml`
    - Include: explicit non-default namespace (`demo-app`), replicas >= 2, CPU/memory requests and limits, securityContext (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities), liveness and readiness probes with all required fields, pinned nginx image tag (not "latest")
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 1.3 Create the non-compliant nginx deployment manifest
    - Create `manifests/non-compliant/deployment.yaml`
    - Intentionally violate at least 4 rules: omit namespace, use replicas: 1, omit resources, omit securityContext, omit probes, use `nginx:latest` image tag
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 2. Implement the Kiro Validate composite GitHub Action
  - [x] 2.1 Create the composite action definition
    - Create `.github/actions/kiro-validate/action.yml`
    - Define required inputs: `manifests-path`, `policy-path`
    - Define output: `report`
    - Reference the shell script as the main run step
    - _Requirements: 1.1, 1.5_

  - [x] 2.2 Implement the action shell script logic
    - Implement in `.github/actions/kiro-validate/action.yml` composite steps (or a referenced script)
    - Use `set -euo pipefail` for strict error handling
    - Validate inputs exist (fail fast with distinct error messages for missing/invalid inputs)
    - Check `KIRO_API_KEY` environment variable is set
    - Install Kiro CLI via official installer
    - Invoke `kiro-cli chat --no-interactive --trust-tools=read,grep` with timeout wrapper (240s)
    - Parse output to determine pass/fail, set `report` output via `$GITHUB_OUTPUT`
    - Exit 0 on pass, exit 1 on violations or errors
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [x] 3. Checkpoint - Validate action and manifests
  - Ensure all files are syntactically valid YAML/markdown, ask the user if questions arise.

- [x] 4. Create the GitHub Actions workflow
  - [x] 4.1 Create the policy gate workflow file
    - Create `.github/workflows/kiro-policy-gate.yml`
    - Trigger on `pull_request` events: `[opened, synchronize]`
    - Define `validate` job with `timeout-minutes: 5`
    - Validate job steps: checkout, run Kiro Validate Action with manifests-path and policy-path inputs, pass `KIRO_API_KEY` secret as env
    - Define `deploy` job with `needs: [validate]` and `if: success()`
    - Deploy job steps: checkout, configure AWS credentials, `kubectl apply -f manifests/`, `kubectl wait --for=condition=Ready pods --all -n demo-app --timeout=120s`
    - Write validation report to `$GITHUB_STEP_SUMMARY` on both success and failure
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 4.2 Add deployment error handling to the workflow
    - Add step summary reporting for kubectl apply failures
    - Add step summary reporting for pod readiness timeout
    - Ensure failure reasons are surfaced in workflow run summary
    - _Requirements: 6.3, 6.4, 6.5, 6.6_

- [x] 5. Checkpoint - Review complete pipeline
  - Ensure all workflow, action, manifest, and policy files are consistent and properly referenced. Ask the user if questions arise.

- [x] 6. Implement smoke tests
  - [x] 6.1 Create policy completeness smoke test
    - Create `tests/smoke/test-policy-completeness.sh`
    - Parse `.kiro/steering/eks-policy.md` and verify all 6 rules are present as distinct sections
    - Verify rule names match: Resource Requests and Limits, Security Context, Health Probes, Image Tag Policy, Namespace Isolation, High Availability
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 6.2 Create manifest compliance smoke test
    - Create `tests/smoke/test-manifest-compliance.sh`
    - Parse `manifests/compliant/deployment.yaml` and verify: explicit non-default namespace, replicas >= 2, resource requests/limits present, securityContext fields, probes present, pinned image tag
    - Parse `manifests/non-compliant/deployment.yaml` and verify: missing namespace, replicas < 2, missing resources, missing securityContext, missing probes, uses "latest" tag
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 6.3 Create workflow structure smoke test
    - Create `tests/smoke/test-workflow-structure.sh`
    - Parse `.github/workflows/kiro-policy-gate.yml` and verify:
      - Trigger is `pull_request: [opened, synchronize]`
      - `validate` job has `timeout-minutes: 5`
      - `deploy` job has `needs: [validate]`
      - Deploy job contains `kubectl apply` and `kubectl wait --timeout=120s`
    - _Requirements: 3.1, 3.4, 3.6, 7.1, 7.2_

  - [x] 6.4 Create action interface smoke test
    - Create `tests/smoke/test-action-interface.sh`
    - Parse `.github/actions/kiro-validate/action.yml` and verify:
      - `manifests-path` input is defined and required
      - `policy-path` input is defined and required
      - `report` output is defined
    - _Requirements: 1.1, 1.5_

  - [ ]* 6.5 Create unit tests for action shell script
    - Create `tests/unit/test-action-script.bats` using bats-core
    - Test input validation: missing manifests-path, missing policy-path, non-existent paths
    - Test KIRO_API_KEY validation: missing env var
    - Test exit code mapping with mocked Kiro CLI (violations → exit 1, no violations → exit 0, crash → exit 1)
    - _Requirements: 1.3, 1.4, 1.6, 1.7_

- [x] 7. Create integration test documentation
  - [x] 7.1 Create integration test README
    - Create `tests/integration/README.md`
    - Document how to run the full pipeline locally (using `act` or GitHub Actions)
    - Document how to test compliant and non-compliant flows
    - Document the remediation flow: non-compliant → fix → re-validate → deploy
    - _Requirements: 6.1, 6.2_

- [x] 8. Final checkpoint - Run smoke tests and verify all artifacts
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The implementation uses Bash for the action script, YAML for workflows/manifests, and Markdown for the policy file
- Property-based testing does not apply — the feature is composed of declarative configs and a thin shell wrapper around Kiro CLI
- Smoke tests use shell scripts with `yq` or `grep` to verify structural correctness
- Unit tests use `bats-core` for Bash script testing
- Integration tests require a real Kiro API key and optionally an EKS cluster
- Checkpoints ensure incremental validation between major implementation phases

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["4.2"] },
    { "id": 5, "tasks": ["6.1", "6.2", "6.3", "6.4"] },
    { "id": 6, "tasks": ["6.5", "7.1"] }
  ]
}
```
