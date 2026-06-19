# Kiro EKS Policy Gate

A GitHub Actions workflow that uses Kiro's headless CLI to validate Kubernetes manifests against an EKS deployment best-practices policy before deploying to a cluster.

## How It Works

On every pull request, the workflow:

1. **Validates** all manifests in `manifests/` against the policy rules defined in `.kiro/steering/eks-policy.md` using the Kiro CLI.
2. **Blocks deployment** if any violations are detected, posting a detailed report to the PR summary.
3. **Deploys** compliant manifests to EKS and verifies pod readiness (only runs when validation passes).

## Policy Rules

The EKS policy enforces six rules on every container and resource:

| # | Rule | Summary |
|---|------|---------|
| 1 | Resource Requests and Limits | CPU/memory requests and limits must be declared |
| 2 | Security Context | Non-root, read-only filesystem, capabilities dropped |
| 3 | Health Probes | Liveness and readiness probes with timing config |
| 4 | Image Tag Policy | No `latest` tag; use pinned versions or SHA digests |
| 5 | Namespace Isolation | Explicit namespace, never `default` |
| 6 | High Availability | Minimum 2 replicas for Deployments/StatefulSets |

The full policy definition lives in [`.kiro/steering/eks-policy.md`](.kiro/steering/eks-policy.md).

## Repository Structure

```
.github/
  actions/kiro-validate/   # Composite action that invokes Kiro CLI
  workflows/               # CI workflow definition
.kiro/
  steering/                # Policy steering files consumed by Kiro
  specs/                   # Feature specs
manifests/
  compliant/               # Example deployment passing all rules
  non-compliant/           # Example deployment violating all rules
tests/
  smoke/                   # Shell-based smoke tests
  integration/             # Integration test scaffolding
```

## Usage

### Prerequisites

- A GitHub repository with Actions enabled.
- A `KIRO_API_KEY` secret configured in the repository settings.
- An `EKS_DEPLOY_ROLE_ARN` secret for the deploy step (IAM role with EKS access).

### Running the Workflow

The workflow triggers automatically on pull requests. No manual setup is needed beyond adding the secrets above.

To validate manifests locally (requires Kiro CLI installed):

```bash
kiro-cli chat --no-interactive --trust-tools=read,grep \
  "Validate manifests/ against .kiro/steering/eks-policy.md"
```

### Adding New Manifests

Place Kubernetes manifest YAML files under `manifests/`. The validation step scans the entire directory recursively.

## Example Manifests

**Compliant** (`manifests/compliant/deployment.yaml`) — passes all six rules with pinned image versions, resource limits, security context, health probes, explicit namespace, and 2 replicas.

**Non-compliant** (`manifests/non-compliant/deployment.yaml`) — intentionally violates every rule for testing purposes.

## Tests

Run the smoke tests locally:

```bash
bash tests/smoke/test-action-interface.sh
bash tests/smoke/test-manifest-compliance.sh
bash tests/smoke/test-policy-completeness.sh
bash tests/smoke/test-workflow-structure.sh
```

## License

Internal use only.
