# Fase4-Orchestrator

Projeto de orquestracao dos microsservicos da Fase 4. Este repositorio centraliza a execucao conjunta das APIs e workers do ecossistema, compartilhando dependencias como RabbitMQ, PostgreSQL, DynamoDB Local, Redis e Elasticsearch.

## Projetos orquestrados

- `Fase4-UsersAPI`: Web API .NET 8 para usuarios, login e emissao de JWT.
- `Fase4-GamesAPI`: Web API .NET 8 para catalogo de jogos e solicitacao de compras.
- `Fase4-PaymentsAPI`: worker .NET 8 que consome `payment-queue` e publica notificacoes.
- `Fase4-NotificationAPI`: worker .NET 8 que consome `notification-queue` e processa notificacoes de email.

## Fluxo principal

1. Users API autentica usuarios e emite tokens JWT.
2. Games API valida o token, consulta/catalogo jogos e publica solicitacoes de compra em `payment-queue`.
3. Payments API consome `PurchaseRequestedEvent`, aprova ou rejeita o pagamento e publica `EmailNotificationEvent` em `notification-queue`.
4. Notification API consome `EmailNotificationEvent` e processa a notificacao.

## Dependencias compartilhadas

- PostgreSQL para Users API.
- DynamoDB Local para Games API em ambiente local.
- Redis para cache da Games API.
- Elasticsearch para indice de busca/catalogo da Games API.
- RabbitMQ como broker compartilhado entre os microsservicos.

Convencoes RabbitMQ:

- Host interno: `rabbitmq`
- Porta AMQP: `5672`
- Porta Management: `15672`
- VHost: `fiap`
- Exchange topic: `fiap.events`
- Fila de pagamentos: `payment-queue`
- Fila de notificacoes: `notification-queue`

## Estrutura esperada do workspace

O orquestrador espera estar na mesma pasta dos demais repositorios:

```text
WIP/
  Fase4-Orchestrator/
  Fase4-UsersAPI/
  Fase4-GamesAPI/
  Fase4-PaymentsAPI/
  Fase4-NotificationAPI/
```

## Execucao local com Docker Compose

Na raiz do `Fase4-Orchestrator`:

```powershell
docker compose up --build
```

Servicos locais:

- Users API: `http://localhost:5000`
- Games API: `http://localhost:5001`
- RabbitMQ Management: `http://localhost:15672`
- PostgreSQL: `localhost:5432`
- DynamoDB Local: `http://localhost:8000`
- Redis: `localhost:6379`
- Elasticsearch: `http://localhost:9200`

## Variaveis de ambiente

Variaveis usadas pelo Docker Compose e pelos scripts Kubernetes:

- `POSTGRES_PASSWORD`
- `USERS_DB_CONNECTION_STRING`
- `JWT_SECRET`
- `JWT_ISSUER`
- `JWT_AUDIENCE`
- `JWT_KEY_ID`
- `RABBITMQ_USERNAME`
- `RABBITMQ_PASSWORD`
- `RABBITMQ_VHOST`
- `LOCAL_AWS_ACCESS_KEY_ID`
- `LOCAL_AWS_SECRET_ACCESS_KEY`

## Kubernetes local

```powershell
.\deployLocalK8s.ps1
```

O script aplica os manifests dos projetos no namespace `fase4`, cria os secrets compartilhados e aguarda os rollouts principais:

- `postgres`
- `rabbitmq`
- `dynamodb-local`
- `elasticsearch`
- `redis`
- `users-api`
- `games-api`
- `payments-worker`
- `notifications-worker`

## Deploy no EKS

```powershell
.\deployEksK8s.ps1 `
  -ClusterName fcg-fase4 `
  -Region us-east-1 `
  -GamesApiRoleArn <role-arn-gerado-pelo-terraform>
```

O script atualiza o kubeconfig, cria/atualiza secrets no namespace `fase4`, aplica dependencias compartilhadas e publica os manifests dos microsservicos no cluster.

## Imagens Docker esperadas

- `adinteltidev/fase4-users-api:latest`
- `adinteltidev/fase4-games-api:latest`
- `adinteltidev/fase4-payments-api:latest`
- `adinteltidev/fase4-notifications-api:latest`

## Documentacao adicional

Consulte tambem:

- `RABBITMQ.md`: convencoes do broker compartilhado.
- README de cada microsservico para comandos isolados, variaveis especificas e detalhes de deploy.
