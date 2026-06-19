# Integration Tests

End-to-end tests that validate the full Kiro EKS Policy Gate pipeline — from manifest validation through deployment.

## Overview

These integration tests exercise the complete CI/CD flow:

1. **Compliant flow** — manifests pass Kiro validation and deploy to EKS
2. **Non-compliant flow** — manifests fail Kiro validation with rule violations listed
3. **Remediation flow** — fix violations, re-validate, and deploy successfully

Unlike the smoke tests (which verify structural correctness of config files), integration tests invoke the actual Kiro CLI and optionally deploy to a real EKS cluster.

## Prerequisites

| Tool | Purpose | Required |
|------|---------|----------|
| [`act`](https://github.com/nektos/act) | Run GitHub Actions workflows locally | Yes (for local testing) |
| `kubectl` | Deploy manifests to EKS | Only for deploy job |
| AWS CLI + credentials | Authenticate to EKS | Only for deploy job |
| `KIRO_API_KEY` | Authenticate with Kiro CLI | Yes |
| `EKS_DEPLOY_ROLE_ARN` | IAM role for EKS deployment | Only for deploy job |
| An EKS cluster | Target cluster for deployment | Only for deploy job |

## Running Locally with `act`

### 1. Install `act`

```bash
# macOS
brew install act

# Linux
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

See https://github.com/nektos/act for other installation methods.

### 2. Create a secrets file

Create a `.secrets` file in the repository root (this file is gitignored):

```bash
KIRO_API_KEY=your-kiro-api-key-here
EKS_DEPLOY_ROLE_ARN=arn:aws:iam::123456789012:role/your-eks-deploy-role
```

### 3. Run the workflow

```bash
# Run the full pipeline (validate + deploy)
act pull_request -W .github/workflows/kiro-policy-gate.yml --secret-file .secrets

# Run only the validate job
act pull_request -W .github/workflows/kiro-policy-gate.yml --secret-file .secrets -j validate
```

## Testing the Compliant Flow

Point the workflow at the compliant manifests to verify a passing validation:

1. Ensure the workflow `manifests-path` input references `manifests/compliant/`:

   ```bash
   # Temporarily edit the workflow or override the input
   act pull_request -W .github/workflows/kiro-policy-gate.yml --secret-file .secrets \
     --env MANIFESTS_PATH=manifests/compliant/
   ```

2. **Expected result:** Kiro validates the manifest, finds zero violations, exits with code 0, and the deploy job proceeds.

The compliant manifest (`manifests/compliant/deployment.yaml`) satisfies all 6 policy rules:
- Explicit namespace (`demo-app`)
- Replicas: 2
- CPU/memory requests and limits
- Security context (runAsNonRoot, readOnlyRootFilesystem, drop ALL)
- Liveness and readiness probes with all timing fields
- Pinned image tag (`nginx:1.27.3`)

## Testing the Non-Compliant Flow

Point the workflow at the non-compliant manifests to verify a failing validation:

1. Ensure the workflow `manifests-path` input references `manifests/non-compliant/`:

   ```bash
   act pull_request -W .github/workflows/kiro-policy-gate.yml --secret-file .secrets \
     --env MANIFESTS_PATH=manifests/non-compliant/
   ```

2. **Expected result:** Kiro validates the manifest, identifies violations, exits with code 1, and the deploy job is skipped.

The non-compliant manifest (`manifests/non-compliant/deployment.yaml`) violates all 6 rules:
- No namespace (defaults to `default`)
- Replicas: 1
- No resource requests or limits
- No security context
- No liveness or readiness probes
- Uses `nginx:latest` image tag

## Remediation Flow

This flow demonstrates the full feedback loop: fail → fix → pass → deploy.

### Step 1: Observe validation failure

Run the workflow against the non-compliant manifest. The validation report will list each violated rule.

### Step 2: Fix the violations

Apply the following corrections to the non-compliant manifest:

| Violation | Fix |
|-----------|-----|
| Missing namespace | Add `namespace: demo-app` to metadata |
| Replicas < 2 | Set `replicas: 2` |
| Missing resources | Add `resources.requests` and `resources.limits` for CPU and memory |
| Missing security context | Add `runAsNonRoot: true` at pod level; add `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]` at container level |
| Missing probes | Add `livenessProbe` and `readinessProbe` with `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold` |
| Uses `latest` tag | Pin to a specific version (e.g., `nginx:1.27.3`) |

See `manifests/compliant/deployment.yaml` as a reference for what the fixed manifest should look like.

### Step 3: Re-run validation

```bash
act pull_request -W .github/workflows/kiro-policy-gate.yml --secret-file .secrets
```

**Expected result:** Validation passes (exit 0).

### Step 4: Deploy to EKS

Once validation passes, the deploy job runs automatically:
- `kubectl apply -f manifests/` applies the fixed manifests
- `kubectl wait --for=condition=Ready pods --all -n demo-app --timeout=120s` verifies pods are healthy

## Running on GitHub Actions

### 1. Push to a branch and open a PR

```bash
git checkout -b my-feature
git push -u origin my-feature
# Open a pull request on GitHub
```

### 2. Automatic trigger

The workflow triggers automatically on `pull_request` events (`opened`, `synchronize`). No manual action needed once the PR is created.

### 3. Configure repository secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `KIRO_API_KEY` | Your Kiro API key for headless validation |
| `EKS_DEPLOY_ROLE_ARN` | The IAM role ARN that has permissions to deploy to your EKS cluster |

### 4. View results

- Check the **Actions** tab for workflow run status
- The validation report appears in the **job summary** section
- On failure, the report lists each violated rule with remediation guidance
