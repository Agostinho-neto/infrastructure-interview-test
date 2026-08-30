param(
    [string]$DatabaseUsername = "test",
    [string]$DatabasePassword = "test",
    [string]$DatabaseRootPassword = "test",
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"

$clusterName = "infrastructure-interview"
$namespace = "infrastructure-interview"
$repositoryRoot = Split-Path -Parent $PSScriptRoot

$requiredCommands = @(
    "docker",
    "kind",
    "kubectl",
    "node"
)

foreach ($command in $requiredCommands) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found in PATH."
    }
}

Write-Host "All required commands are available."

$clusterConfig = Join-Path $repositoryRoot "infra\kind\cluster.yaml"
$kubeContext = "kind-$clusterName"

$existingClusters = @(kind get clusters)

if ($LASTEXITCODE -ne 0) {
    throw "Unable to list Kind clusters. Check whether Docker Desktop is running."
}

if ($existingClusters -contains $clusterName) {
    Write-Host "Kind cluster '$clusterName' already exists."
}
else {
    Write-Host "Creating Kind cluster '$clusterName'..."

    kind create cluster --config $clusterConfig

    if ($LASTEXITCODE -ne 0) {
        throw "Kind cluster creation failed."
    }
}

kubectl get nodes --context $kubeContext

if ($LASTEXITCODE -ne 0) {
    throw "Unable to access Kubernetes context '$kubeContext'."
}

$kubernetesDirectory = Join-Path $repositoryRoot "infra\kubernetes"

Write-Host "Applying namespace and application configuration..."

kubectl apply --context $kubeContext `
    -f (Join-Path $kubernetesDirectory "namespace.yaml") `
    -f (Join-Path $kubernetesDirectory "configmap.yaml")

if ($LASTEXITCODE -ne 0) {
    throw "Unable to apply namespace or ConfigMap."
}

$secretName = "database-credentials"

$existingSecret = kubectl get secret $secretName `
    --namespace $namespace `
    --context $kubeContext `
    --output name 2>$null

if ([string]::IsNullOrWhiteSpace($existingSecret)) {
    Write-Host "Creating local database credentials..."

    kubectl create secret generic $secretName `
        --namespace $namespace `
        --context $kubeContext `
        "--from-literal=username=$DatabaseUsername" `
        "--from-literal=password=$DatabasePassword" `
        "--from-literal=root-password=$DatabaseRootPassword"

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create database credentials."
    }
}
else {
    Write-Host "Database credentials already exist."
}

Write-Host "Deploying MariaDB..."

kubectl apply --context $kubeContext `
    -f (Join-Path $kubernetesDirectory "mariadb-service.yaml") `
    -f (Join-Path $kubernetesDirectory "mariadb-statefulset.yaml")

if ($LASTEXITCODE -ne 0) {
    throw "Unable to deploy MariaDB."
}

kubectl rollout status statefulset/mariadb `
    --namespace $namespace `
    --context $kubeContext `
    --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "MariaDB did not become ready within the expected time."
}

Write-Host "Running database migrations..."

kubectl delete job database-migration `
    --namespace $namespace `
    --context $kubeContext `
    --ignore-not-found=true

if ($LASTEXITCODE -ne 0) {
    throw "Unable to remove the previous migration Job."
}

kubectl apply --context $kubeContext `
    -f (Join-Path $kubernetesDirectory "database-migration-job.yaml")

if ($LASTEXITCODE -ne 0) {
    throw "Unable to create the migration Job."
}

kubectl wait `
    --for=condition=complete `
    job/database-migration `
    --namespace $namespace `
    --context $kubeContext `
    --timeout=180s

if ($LASTEXITCODE -ne 0) {
    kubectl logs job/database-migration `
        --namespace $namespace `
        --context $kubeContext

    throw "Database migration failed."
}

kubectl logs job/database-migration `
    --namespace $namespace `
    --context $kubeContext

Write-Host "Deploying application..."

kubectl apply --context $kubeContext `
    -f (Join-Path $kubernetesDirectory "app-deployment.yaml") `
    -f (Join-Path $kubernetesDirectory "app-service.yaml") `
    -f (Join-Path $kubernetesDirectory "app-pdb.yaml")

if ($LASTEXITCODE -ne 0) {
    throw "Unable to deploy the application."
}

kubectl rollout status deployment/interview-app `
    --namespace $namespace `
    --context $kubeContext `
    --timeout=180s

if ($LASTEXITCODE -ne 0) {
    throw "The application did not become ready within the expected time."
}

kubectl get pods `
    --namespace $namespace `
    --context $kubeContext `
    --selector app=interview-app `
    --output wide

Write-Host "Running application smoke tests..."

$smokeTestPath = Join-Path $repositoryRoot "tests\smoke-test.js"
$env:BASE_URL = $BaseUrl

node $smokeTestPath

if ($LASTEXITCODE -ne 0) {
    throw "Application smoke tests failed."
}

Write-Host "Local deployment completed successfully."
Write-Host "Application URL: $BaseUrl/posts"