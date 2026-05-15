# RabbitMQ compartilhado

As APIs `Fase4-UsersAPI` e `Fase4-GamesAPI` foram padronizadas para usar o mesmo broker RabbitMQ quando executadas juntas.

## Convencoes

- Host interno Docker/Kubernetes: `rabbitmq`
- Porta AMQP: `5672`
- Porta Management: `15672`
- Usuario: `admin`
- Senha local: definida pela variavel de ambiente `RABBITMQ_PASSWORD`
- VHost: `fiap`
- Exchange topic: `fiap.events`
- Fila da Users API: `notification-queue`
- Fila da Games API: `payment-queue`

Cada publisher declara sua fila de forma idempotente, declara a exchange `fiap.events` e cria o binding usando o nome da fila como routing key.

## Rodar as duas APIs juntas

Na raiz do workspace:

```powershell
docker compose up --build
```

Servicos:

- Users API: `http://localhost:5000`
- Games API: `http://localhost:5001`
- RabbitMQ Management: `http://localhost:15672`
- DynamoDB Local: `http://localhost:8000`
- PostgreSQL: `localhost:5432`

## Kubernetes

Ambos os repositorios agora usam o mesmo recurso Kubernetes:

- `Secret/rabbitmq-secrets`
- `Service/rabbitmq`
- `Deployment/rabbitmq`
- Namespace `fase4`

Os scripts de deploy aplicam os manifests de forma incremental e nao apagam mais o namespace da Users API, preservando outros microservicos e o RabbitMQ compartilhado.

## Rodar no mesmo cluster Kubernetes

Para rodar Users API e Games API juntas no Kubernetes local:

```powershell
.\deployLocalK8s.ps1
```

Para rodar as duas no mesmo cluster EKS:

```powershell
.\deployEksK8s.ps1 -ClusterName Fcg-Fase4 -Region us-east-1 -GamesApiRoleArn <role-arn>
```

Os manifests individuais de cada repositorio tambem continuam funcionando de forma isolada, pois todos usam o mesmo namespace `fase4` e os mesmos nomes para os recursos compartilhados.
