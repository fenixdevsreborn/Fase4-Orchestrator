param(
  [string]$Namespace = "fase4"
)

$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$UsersLocalDir = Join-Path $RootDir "Fase3-UsersAPI/k8s/local"
$GamesLocalDir = Join-Path $RootDir "Fase3-GamesAPI/k8s/local"

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

Write-Host "Aplicando namespace compartilhado..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersLocalDir "00-namespace.yaml")

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
  "--from-literal=jwt-key-id=$(Require-Env 'JWT_KEY_ID')",
  "--from-literal=aws-access-key-id=$(Require-Env 'LOCAL_AWS_ACCESS_KEY_ID')",
  "--from-literal=aws-secret-access-key=$(Require-Env 'LOCAL_AWS_SECRET_ACCESS_KEY')"
)
Apply-Secret "rabbitmq-secrets" @(
  "--from-literal=rabbitmq-user=$(Require-Env 'RABBITMQ_USERNAME')",
  "--from-literal=rabbitmq-pass=$(Require-Env 'RABBITMQ_PASSWORD')",
  "--from-literal=rabbitmq-vhost=$(Require-Env 'RABBITMQ_VHOST')"
)

Write-Host "Aplicando dependencias compartilhadas e bancos locais..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersLocalDir "02-postgres.yaml")
kubectl apply -f (Join-Path $UsersLocalDir "03-rabbitmq.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "03-dynamodb-local.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "03-dynamodb-init-job.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "03-elasticsearch.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "03-redis.yaml")

Write-Host "Aplicando microsservicos..." -ForegroundColor Green
kubectl apply -f (Join-Path $UsersLocalDir "04-users-api.yaml")
kubectl apply -f (Join-Path $UsersLocalDir "05-service.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "04-games-api.yaml")
kubectl apply -f (Join-Path $GamesLocalDir "05-service.yaml")

Write-Host "Aguardando pods principais..." -ForegroundColor Cyan
kubectl rollout status deployment/rabbitmq -n $Namespace
kubectl rollout status deployment/postgres -n $Namespace
kubectl rollout status deployment/dynamodb-local -n $Namespace
kubectl rollout status deployment/elasticsearch -n $Namespace
kubectl rollout status deployment/redis -n $Namespace
kubectl rollout status deployment/users-api -n $Namespace
kubectl rollout status deployment/games-api -n $Namespace

kubectl get pods -n $Namespace -o wide
kubectl get svc -n $Namespace
