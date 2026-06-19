# EKS Deployment Best Practices Policy

This steering file defines mandatory security and operational rules for Kubernetes deployments targeting AWS EKS clusters. When validating Kubernetes manifests, check each rule below and report any violations with the rule identifier and remediation guidance.

---

## Rule 1: Resource Requests and Limits

**Description:** All containers in a pod specification must declare explicit CPU and memory resource requests and limits. This ensures the Kubernetes scheduler can make informed placement decisions and prevents resource contention between workloads.

**What to check:**
- Every container in `spec.template.spec.containers[]` must have `resources.requests.cpu` defined
- Every container must have `resources.requests.memory` defined
- Every container must have `resources.limits.cpu` defined
- Every container must have `resources.limits.memory` defined
- Resource requests MUST be less than or equal to their corresponding limits

**Compliant example:**
```yaml
containers:
  - name: nginx
    image: nginx:1.27.3
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

**Non-compliant example:**
```yaml
containers:
  - name: nginx
    image: nginx:latest
    # No resources section — violates Rule 1
```

---

## Rule 2: Security Context

**Description:** All containers must run with a restricted security context to minimize the attack surface. Containers must run as non-root, use a read-only root filesystem, and drop all Linux capabilities by default. Only explicitly needed capabilities may be added back.

**What to check:**
- Pod-level or container-level `securityContext.runAsNonRoot` must be set to `true`
- Container-level `securityContext.readOnlyRootFilesystem` must be set to `true`
- Container-level `securityContext.capabilities.drop` must include `"ALL"`
- Only explicitly needed capabilities may appear in `securityContext.capabilities.add`

**Compliant example:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
  containers:
    - name: nginx
      securityContext:
        readOnlyRootFilesystem: true
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
```

**Non-compliant example:**
```yaml
spec:
  # No pod-level securityContext
  containers:
    - name: nginx
      # No container-level securityContext — violates Rule 2
```

---

## Rule 3: Health Probes

**Description:** All containers must define both liveness and readiness probes to enable Kubernetes to detect unhealthy pods and manage traffic routing. Each probe must include timing configuration to avoid premature restarts or delayed traffic routing.

**What to check:**
- Every container must have a `livenessProbe` defined
- Every container must have a `readinessProbe` defined
- Each probe must specify `initialDelaySeconds`
- Each probe must specify `periodSeconds`
- Each probe must specify `timeoutSeconds`
- Each probe must specify `failureThreshold`

**Compliant example:**
```yaml
containers:
  - name: nginx
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
      initialDelaySeconds: 10
      periodSeconds: 10
      timeoutSeconds: 3
      failureThreshold: 3
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
      timeoutSeconds: 3
      failureThreshold: 3
```

**Non-compliant example:**
```yaml
containers:
  - name: nginx
    # No livenessProbe — violates Rule 3
    # No readinessProbe — violates Rule 3
```

---

## Rule 4: Image Tag Policy

**Description:** Container images must reference a specific, immutable version to ensure reproducible deployments and prevent unexpected changes when images are updated upstream. The "latest" tag is mutable and must not be used.

**What to check:**
- The `image` field must NOT use the `latest` tag (e.g., `nginx:latest` is not allowed)
- The `image` field must NOT omit the tag entirely (bare image names like `nginx` default to latest)
- The `image` field must reference a specific version tag (e.g., `nginx:1.27.3`) or a SHA256 digest (e.g., `nginx@sha256:abc123...`)

**Compliant example:**
```yaml
containers:
  - name: nginx
    image: nginx:1.27.3
```

```yaml
containers:
  - name: nginx
    image: nginx@sha256:6db391d1c0cfb30588ba0bf72ea999404f2764e2d42e4002ee4c1e9f89e75a4d
```

**Non-compliant example:**
```yaml
containers:
  - name: nginx
    image: nginx:latest   # Violates Rule 4 — uses "latest" tag
```

```yaml
containers:
  - name: nginx
    image: nginx          # Violates Rule 4 — no tag defaults to "latest"
```

---

## Rule 5: Namespace Isolation

**Description:** All Kubernetes resources must declare an explicit namespace in their metadata to ensure proper workload isolation and avoid accidental deployment into the default namespace, which lacks network policies and resource quotas in most clusters.

**What to check:**
- The `metadata.namespace` field must be present on every resource
- The `metadata.namespace` value must NOT be `"default"`

**Compliant example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-compliant
  namespace: demo-app     # Explicit non-default namespace
```

**Non-compliant example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-non-compliant
  # No namespace field — violates Rule 5 (defaults to "default")
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-non-compliant
  namespace: default      # Violates Rule 5 — must not use "default"
```

---

## Rule 6: High Availability

**Description:** Deployments and StatefulSets must specify a minimum replica count of 2 to ensure high availability. A single replica creates a single point of failure where pod eviction, node failure, or rolling updates cause downtime.

**What to check:**
- Resources of kind `Deployment` must have `spec.replicas` set to 2 or greater
- Resources of kind `StatefulSet` must have `spec.replicas` set to 2 or greater
- The `replicas` field must be explicitly specified (not omitted)

**Compliant example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-compliant
spec:
  replicas: 2            # Meets minimum HA requirement
```

**Non-compliant example:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-non-compliant
spec:
  replicas: 1            # Violates Rule 6 — must be >= 2
```
