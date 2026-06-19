# Requirements Document

## Introduction

This feature implements a demo CI/CD pipeline on GitHub Actions that uses Kiro headless as an AI-powered policy gate to validate pull requests against EKS deployment best practices. The pipeline enforces that Kubernetes manifests comply with a predefined security and operational policy before allowing deployment to an AWS EKS cluster. Two sample deployments (nginx-based) demonstrate the pass/fail behavior: one compliant deployment passes validation, and one non-compliant deployment fails initially, gets fixed, and then deploys successfully.

## Glossary

- **Kiro_Headless**: The headless (non-interactive) mode of Kiro AI that can be invoked programmatically to perform code analysis and validation against policies
- **Policy_Gate**: A CI/CD checkpoint that uses Kiro_Headless to validate Kubernetes manifests against a predefined set of EKS deployment best practices before allowing deployment
- **EKS_Policy**: A steering file containing best practices and security rules for deploying applications to AWS EKS clusters
- **GitHub_Actions_Workflow**: A CI/CD pipeline defined in YAML that runs on GitHub Actions runners to automate validation and deployment
- **Kiro_Validation_Action**: A reusable GitHub Action that wraps Kiro_Headless invocation to validate Kubernetes manifests against the EKS_Policy
- **Compliant_Deployment**: A Kubernetes deployment manifest (nginx) that follows all EKS best practices defined in the EKS_Policy
- **Non_Compliant_Deployment**: A Kubernetes deployment manifest (nginx) that intentionally violates one or more rules in the EKS_Policy
- **Kubernetes_Manifest**: A YAML file defining Kubernetes resources such as Deployments, Services, and ConfigMaps for deploying applications to EKS

## Requirements

### Requirement 1: Kiro Validation GitHub Action

**User Story:** As a platform engineer, I want a reusable GitHub Action that invokes Kiro headless to validate Kubernetes manifests against a policy, so that I can enforce deployment standards in any repository's CI/CD pipeline.

#### Acceptance Criteria

1. THE Kiro_Validation_Action SHALL accept a required input for the path to Kubernetes manifests and a required input for the path to the EKS_Policy steering file
2. WHEN invoked, THE Kiro_Validation_Action SHALL execute Kiro_Headless in validation mode against the specified manifests using the EKS_Policy as context
3. WHEN Kiro_Headless identifies policy violations, THE Kiro_Validation_Action SHALL exit with a non-zero status code
4. WHEN Kiro_Headless finds no policy violations, THE Kiro_Validation_Action SHALL exit with a zero status code
5. THE Kiro_Validation_Action SHALL output a validation report to stdout and as a GitHub Actions step output named "report", including each violated rule and its remediation guidance
6. IF a required input is missing or references a path that does not exist, THEN THE Kiro_Validation_Action SHALL exit with a non-zero status code and output an error message indicating which input is invalid
7. IF Kiro_Headless fails to execute or returns an unexpected error, THEN THE Kiro_Validation_Action SHALL exit with a non-zero status code and output an error message indicating the execution failure

### Requirement 2: EKS Deployment Policy Definition

**User Story:** As a platform engineer, I want a comprehensive EKS best practices policy defined as a steering file, so that Kiro headless can validate deployments against established security and operational standards.

#### Acceptance Criteria

1. THE EKS_Policy SHALL define resource limit and request requirements for all containers, mandating that both CPU and memory requests and limits are explicitly specified for every container in a pod specification
2. THE EKS_Policy SHALL define security context rules requiring that all containers run as non-root (runAsNonRoot: true), use a read-only root filesystem (readOnlyRootFilesystem: true), and drop ALL capabilities with only explicitly needed capabilities added back
3. THE EKS_Policy SHALL define liveness and readiness probe requirements for all containers, mandating that both probes are configured with initialDelaySeconds, periodSeconds, timeoutSeconds, and failureThreshold explicitly specified
4. THE EKS_Policy SHALL define image tag policy prohibiting the use of the "latest" tag and requiring that all container images reference a specific version tag or SHA256 digest
5. THE EKS_Policy SHALL define namespace isolation rules requiring that all manifests include an explicit namespace field set to a value other than "default"
6. THE EKS_Policy SHALL define a minimum replica count of 2 for all Deployment and StatefulSet resources to support high availability
7. THE EKS_Policy SHALL be formatted as a Kiro steering file in markdown format with each rule expressed as a distinct, parseable section that Kiro_Headless can use as validation context

### Requirement 3: GitHub Actions Pipeline Integration

**User Story:** As a developer, I want the Kiro validation to run automatically on pull requests, so that non-compliant deployments are blocked before merging.

#### Acceptance Criteria

1. WHEN a pull request is opened or updated, THE GitHub_Actions_Workflow SHALL trigger the Kiro_Validation_Action against the Kubernetes manifests in the pull request
2. WHEN the Kiro_Validation_Action exits with a non-zero status code, THE GitHub_Actions_Workflow SHALL mark the pull request check as failed and make the validation output available in the check run summary
3. WHEN the Kiro_Validation_Action exits with a zero status code, THE GitHub_Actions_Workflow SHALL mark the pull request check as passed
4. THE GitHub_Actions_Workflow SHALL require the Kiro validation check to pass before the pull request can be merged
5. WHEN the Kiro_Validation_Action passes successfully, THE GitHub_Actions_Workflow SHALL proceed to the deployment step
6. IF the Kiro_Validation_Action fails to complete within 5 minutes or encounters an infrastructure error, THEN THE GitHub_Actions_Workflow SHALL mark the pull request check as failed and indicate that the failure was due to an execution error rather than a validation violation
7. WHEN the Kiro_Validation_Action completes, THE GitHub_Actions_Workflow SHALL display the validation output log within the GitHub Actions check run details so that the developer can identify which manifests failed and why

### Requirement 4: Compliant Deployment Sample

**User Story:** As a developer reviewing the demo, I want a sample deployment that passes all policy checks, so that I can understand what a compliant EKS deployment looks like.

#### Acceptance Criteria

1. THE Compliant_Deployment SHALL define an nginx-based Kubernetes Deployment with explicit CPU and memory resource requests and limits, where requests are less than or equal to limits for both CPU and memory
2. THE Compliant_Deployment SHALL configure a security context with runAsNonRoot set to true, readOnlyRootFilesystem set to true, and all capabilities dropped
3. THE Compliant_Deployment SHALL include liveness and readiness probe definitions, each specifying a probe type (httpGet, tcpSocket, or exec), a port, an initialDelaySeconds value, and a periodSeconds value
4. THE Compliant_Deployment SHALL reference the nginx container image with a pinned version tag that is not "latest" and is not empty
5. THE Compliant_Deployment SHALL declare an explicit namespace in the resource metadata
6. THE Compliant_Deployment SHALL specify a replica count of at least 2
7. WHEN validated against the EKS_Policy, THE Kiro_Validation_Action SHALL exit with a zero status code and report zero policy violations for the Compliant_Deployment

### Requirement 5: Non-Compliant Deployment Sample

**User Story:** As a developer reviewing the demo, I want a sample deployment that fails policy checks, so that I can understand what violations look like and how to fix them.

#### Acceptance Criteria

1. THE Non_Compliant_Deployment SHALL define an nginx-based Kubernetes Deployment that violates at least four rules from the EKS_Policy
2. THE Non_Compliant_Deployment SHALL omit CPU and memory resource requests and limits for all containers
3. THE Non_Compliant_Deployment SHALL use the "latest" image tag for the nginx container
4. THE Non_Compliant_Deployment SHALL omit security context configuration at both the pod and container level, including runAsNonRoot, readOnlyRootFilesystem, and capability drop settings
5. THE Non_Compliant_Deployment SHALL omit liveness and readiness probe definitions for all containers
6. THE Non_Compliant_Deployment SHALL omit an explicit namespace declaration, relying on the default namespace
7. WHEN validated against the EKS_Policy, THE Kiro_Validation_Action SHALL exit with a non-zero status code for the Non_Compliant_Deployment
8. WHEN validated against the EKS_Policy, THE Kiro_Validation_Action SHALL output a report identifying each violated rule from the EKS_Policy for the Non_Compliant_Deployment

### Requirement 6: Remediation and Redeployment Flow

**User Story:** As a developer, I want the non-compliant deployment to be fixable so that after applying corrections it passes validation and deploys to EKS, demonstrating the full feedback loop.

#### Acceptance Criteria

1. WHEN the Non_Compliant_Deployment is corrected to comply with all EKS_Policy rules, THE Kiro_Validation_Action SHALL exit with a zero status code
2. WHEN the Kiro_Validation_Action exits with a zero status code for a corrected deployment, THE GitHub_Actions_Workflow SHALL proceed with deployment to the EKS cluster
3. WHEN the GitHub_Actions_Workflow proceeds with deployment, THE GitHub_Actions_Workflow SHALL use kubectl apply to deploy the validated Kubernetes manifests to the EKS cluster
4. WHEN kubectl apply completes with a zero exit code, THE GitHub_Actions_Workflow SHALL verify that all pods defined in the manifests reach Ready status within 120 seconds
5. IF kubectl apply exits with a non-zero exit code, THEN THE GitHub_Actions_Workflow SHALL fail the workflow run and report an error message indicating the deployment command failed
6. IF the pods do not reach Ready status within 120 seconds, THEN THE GitHub_Actions_Workflow SHALL fail the workflow run and report an error message indicating the pod readiness check timed out

### Requirement 7: Deployment Gating

**User Story:** As a platform engineer, I want deployments to be gated by Kiro validation, so that only policy-compliant manifests reach the EKS cluster.

#### Acceptance Criteria

1. THE GitHub_Actions_Workflow SHALL define the deployment job with an explicit dependency on the Kiro validation job such that the deployment job cannot start until the validation job has completed
2. WHILE the Kiro_Validation_Action has not completed with a zero exit status code, THE GitHub_Actions_Workflow SHALL prevent the deployment job from executing
3. IF the Kiro_Validation_Action fails, THEN THE GitHub_Actions_Workflow SHALL skip the deployment job and surface the failure reason in the workflow run summary
4. WHEN the Kiro_Validation_Action succeeds, THE GitHub_Actions_Workflow SHALL execute the deployment job to apply manifests to the EKS cluster
5. IF the deployment job fails after the Kiro_Validation_Action has succeeded, THEN THE GitHub_Actions_Workflow SHALL report the deployment failure reason in the workflow run summary and terminate the workflow with a non-zero exit status
