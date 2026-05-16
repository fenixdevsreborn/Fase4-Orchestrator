param(
  [string]$Namespace = "fase4",
  [string]$Region = "us-east-1",
  [string]$ClusterName = "fcg-fase4",
  [string]$GamesApiRoleArn = ""
)

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$UsersEksDir = Join-Path $RootDir "Fase3-UsersAPI/k8s/eks"
$GamesEksDir = Join-Path $RootDir "Fase3-GamesAPI/k8s/eks"
$NotificationsK8sDir = Join-Path $RootDir "Fase4-NotificationAPI/k8s"

function Require-Env([string]$Name) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Environment variable '$Name' is required to create Kubernetes secrets."
  }
  return $value
}

function Apply-Secret([string]$Name, [string[]]$Literals) {
  kubectl create secret generic $Name -n $Namespace @Literals --dry-run=client -o yaml | kubectl apply -f -
}

aws eks update-kubeconfig --name $ClusterName --region $Region

Write-Host "Aplicando namespace compartilhado..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersEksDir "00-namespace.yaml")

Write-Host "Criando secrets dos microservicos e RabbitMQ compartilhado a partir de variaveis de ambiente..." -ForegroundColor Green
Apply-Secret "app-secrets" @(
  "--from-literal=db-connection=$(Require-Env 'USERS_DB_CONNECTION_STRING')",
  "--from-literal=db-password=$(Require-Env 'POSTGRES_PASSWORD')",
  "--from-literal=jwt-secret=$(Require-Env 'JWT_SECRET')",
  "--from-literal=jwt-issuer=$(Require-Env 'JWT_ISSUER')",
  "--from-literal=jwt-audience=$(Require-Env 'JWT_AUDIENCE')",
  "--from-literal=jwt-key-id=$(Require-Env 'JWT_KEY_ID')"
)
Apply-Secret "games-api-secrets" @(
  "--from-literal=jwt-secret=$(Require-Env 'JWT_SECRET')",
  "--from-literal=jwt-issuer=$(Require-Env 'JWT_ISSUER')",
  "--from-literal=jwt-audience=$(Require-Env 'JWT_AUDIENCE')",
  "--from-literal=jwt-key-id=$(Require-Env 'JWT_KEY_ID')"
)
Apply-Secret "rabbitmq-secrets" @(
  "--from-literal=rabbitmq-user=$(Require-Env 'RABBITMQ_USERNAME')",
  "--from-literal=rabbitmq-pass=$(Require-Env 'RABBITMQ_PASSWORD')",
  "--from-literal=rabbitmq-vhost=$(Require-Env 'RABBITMQ_VHOST')"
)
kubectl apply -f (Join-Path $GamesEksDir "02-serviceaccount.yaml")

if ($GamesApiRoleArn -ne "") {
  kubectl annotate serviceaccount games-api `
    eks.amazonaws.com/role-arn=$GamesApiRoleArn `
    -n $Namespace `
    --overwrite
}

Write-Host "Aplicando dependencias compartilhadas..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersEksDir "02-postgres-pvc.yaml")
kubectl apply -f (Join-Path $UsersEksDir "02-postgres.yaml")
kubectl apply -f (Join-Path $UsersEksDir "03-rabbitmq.yaml")
kubectl apply -f (Join-Path $GamesEksDir "03-elasticsearch.yaml")
kubectl apply -f (Join-Path $GamesEksDir "03-redis.yaml")

Write-Host "Aplicando microsservicos..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersEksDir "04-users-api.yaml")
kubectl apply -f (Join-Path $UsersEksDir "05-service.yaml")
kubectl apply -f (Join-Path $UsersEksDir "06-hpa.yaml")
kubectl apply -f (Join-Path $UsersEksDir "07-ingress.yaml")
kubectl apply -f (Join-Path $NotificationsK8sDir "notifications-configmap.yml")
kubectl apply -f (Join-Path $NotificationsK8sDir "notifications-worker-deployment.yml")
kubectl apply -f (Join-Path $GamesEksDir "04-games-api.yaml")
kubectl apply -f (Join-Path $GamesEksDir "05-service.yaml")
kubectl apply -f (Join-Path $GamesEksDir "06-hpa.yaml")
kubectl apply -f (Join-Path $GamesEksDir "07-ingress.yaml")

Write-Host "Aguardando pods principais..." -ForegroundColor Cyan
kubectl rollout status deployment/rabbitmq -n $Namespace
kubectl rollout status statefulset/postgres -n $Namespace
kubectl rollout status deployment/elasticsearch -n $Namespace
kubectl rollout status deployment/redis -n $Namespace
kubectl rollout status deployment/users-api -n $Namespace
kubectl rollout status deployment/notifications-worker -n $Namespace
kubectl rollout status deployment/games-api -n $Namespace

kubectl get pods -n $Namespace -o wide
kubectl get svc -n $Namespace
kubectl get ingress -n $Namespace
