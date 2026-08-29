# Local Kubernetes environment

This folder contains the files used to run the application in a local Kubernetes cluster with Kind.

The environment was created to reproduce the main production concerns of the exercise without requiring a cloud account. Kind simulates three availability zones, but they are still containers running on the same local machine.

## Structure

- `kind/cluster.yaml`: creates the local cluster with one control-plane and three workers.
- `kubernetes/namespace.yaml`: creates an isolated namespace for the application.
- `kubernetes/configmap.yaml`: stores non-sensitive application configuration.
- `kubernetes/mariadb-service.yaml`: provides an internal address for the database.
- `kubernetes/mariadb-statefulset.yaml`: runs MariaDB with persistent local storage.
- `kubernetes/database-migration-job.yaml`: applies pending database migrations.
- `kubernetes/app-deployment.yaml`: runs three application replicas.
- `kubernetes/app-service.yaml`: exposes the application through a NodePort.
- `kubernetes/app-pdb.yaml`: keeps at least two application replicas available during voluntary disruptions.

## Requirements

- Docker Desktop
- Kind
- kubectl

## Running locally

Create the cluster:

```bash
kind create cluster --config infra/kind/cluster.yaml
```

Confirm that the nodes are ready and check their zone labels:

```bash
kubectl get nodes -L topology.kubernetes.io/zone
```

Create the namespace and application configuration:

```bash
kubectl apply -f infra/kubernetes/namespace.yaml
kubectl apply -f infra/kubernetes/configmap.yaml
```

Create the database credentials. The values below are only for this local environment and are intentionally not stored in the repository:

```bash
kubectl create secret generic database-credentials -n infrastructure-interview --from-literal=username=test --from-literal=password=test --from-literal=root-password=test
```

Start MariaDB and wait until it is ready:

```bash
kubectl apply -f infra/kubernetes/mariadb-service.yaml
kubectl apply -f infra/kubernetes/mariadb-statefulset.yaml
kubectl rollout status statefulset/mariadb -n infrastructure-interview --timeout=180s
```

Run the database migration:

```bash
kubectl apply -f infra/kubernetes/database-migration-job.yaml
kubectl wait --for=condition=complete job/database-migration -n infrastructure-interview --timeout=180s
kubectl logs job/database-migration -n infrastructure-interview
```

Deploy and expose the application:

```bash
kubectl apply -f infra/kubernetes/app-deployment.yaml
kubectl apply -f infra/kubernetes/app-service.yaml
kubectl apply -f infra/kubernetes/app-pdb.yaml
kubectl rollout status deployment/interview-app -n infrastructure-interview --timeout=180s
```

The API is available at:

```text
http://localhost:8080/posts
```

Useful validation commands:

```bash
kubectl get pods -n infrastructure-interview -o wide
kubectl get services -n infrastructure-interview
kubectl get pdb -n infrastructure-interview
```

The pod list should show the three application replicas distributed between workers in different zones.

## Main decisions

- The application image is public and pinned by tag and digest, making the deployed content reproducible.
- Three replicas and topology spread constraints distribute the application across the three simulated zones.
- Readiness and liveness probes prevent unavailable containers from receiving traffic and allow Kubernetes to restart unhealthy containers.
- Resource requests and limits help scheduling and prevent one container from consuming all node resources.
- The containers run as a non-root user with restricted privileges.
- Database schema changes are handled by a migration Job. Automatic schema synchronization is disabled.
- MariaDB uses a StatefulSet and a persistent volume so its data survives a pod restart in the local cluster.

## Production considerations

This setup demonstrates the deployment locally, but some components would be different in a real production environment:

- The database currently has one replica and is not highly available. In production, a managed multi-zone database with backups would be preferred.
- Credentials should come from a secret manager, such as Azure Key Vault, instead of being created manually.
- NodePort is suitable for this local test. A production environment would normally use an Ingress or LoadBalancer with TLS.
- Kind zone labels only simulate availability zones. Real resilience requires nodes in separate physical zones.
- Migrations should run as a controlled step in the deployment pipeline before the new application version is released.

## Cleanup

Remove the local cluster and all resources created inside it:

```bash
kind delete cluster --name infrastructure-interview
```
