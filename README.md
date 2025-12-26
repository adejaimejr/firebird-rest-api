# Firebird REST API Gateway

> Gateway REST API em Node.js para executar queries SQL no Firebird a partir do n8n, Make.com ou qualquer cliente HTTP.

[![Node.js](https://img.shields.io/badge/Node.js-18+-green.svg)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Firebird](https://img.shields.io/badge/Firebird-3.0+-red.svg)](https://firebirdsql.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Sobre

Este projeto foi criado para permitir que ferramentas de automação como **n8n** e **Make.com** possam consultar bancos de dados Firebird (comumente usado em ERPs como Millennium, Sankhya, Dealer, entre outros) através de uma API REST simples e segura.

### ✨ Características

- ✅ **Retorna objetos JSON com nomes de colunas** - Pronto para uso em n8n/Make
- ✅ **Gateway Genérico** - Executa qualquer query SQL sem necessidade de mapear tabelas
- ✅ **Pool de Conexões** - Gerenciamento eficiente de conexões Firebird
- ✅ **Firebird 3.0+ Native** - Suporte completo com `node-firebird-driver-native`
- ✅ **WireCrypt Automático** - Conexão criptografada transparente
- ✅ **Segurança Robusta**:
  - Autenticação via API Key
  - Proteção contra DDL destrutivas (DROP, TRUNCATE, ALTER)
  - Controle de operações de escrita (UPDATE, INSERT, DELETE)
  - Rate limiting configurável
  - Headers de segurança via Helmet.js
- ✅ **Alta Disponibilidade**:
  - Deploy em Docker Swarm com múltiplas réplicas
  - Graceful shutdown sem perda de conexões
  - Health checks para monitoramento
- ✅ **Integração Traefik** - SSL automático via Let's Encrypt
- ✅ **Logs de Auditoria** - Registro de todas as queries executadas

## 🎯 Casos de Uso

- Integrar **ERP Millennium** com n8n para automações
- Consultar dados do Firebird a partir de ferramentas low-code/no-code
- Criar webhooks e APIs REST sobre bases Firebird legadas
- Dashboards em tempo real consultando Firebird
- Integrações entre sistemas sem modificar o ERP

## 🚀 Início Rápido

### Pré-requisitos

- Docker e Docker Swarm (ou Docker Compose)
- Acesso a um servidor Firebird 3.0+
- (Opcional) Traefik configurado para SSL automático

### Instalação em 3 passos

```bash
# 1. Clone o repositório
git clone https://github.com/seu-usuario/firebird-rest-api.git
cd firebird-rest-api

# 2. Configure as variáveis de ambiente
cp .env.example .env
nano .env  # Edite com suas configurações

# 3. Suba os containers
docker-compose up -d
```

### Configuração Mínima (.env)

```bash
# API
API_KEY=gere-uma-chave-forte-aqui  # Use: openssl rand -hex 32

# Domínio (para Traefik SSL)
DOMAIN=api.seudominio.com.br  # Seu domínio público

# Firebird
FB_HOST=192.168.1.10
FB_PORT=3050
FB_DATABASE=/caminho/completo/para/banco.fdb
FB_USER=SYSDBA
FB_PASSWORD=masterkey

# Segurança
BLOCK_DDL=true              # Bloqueia DROP, TRUNCATE, ALTER
ALLOW_WRITE_OPS=false       # Permite UPDATE, INSERT, DELETE
```

> 💡 **Dica**: Gere uma API Key forte com `openssl rand -hex 32`

## 📖 Uso da API

### Executar Query (POST /query)

```bash
curl -X POST https://sua-api.com/query \
  -H "Content-Type: application/json" \
  -H "x-api-key: sua-api-key" \
  -d '{
    "sql": "SELECT FIRST 10 COD_PRODUTO, DESCRICAO, PRECO FROM PRODUTOS WHERE ATIVO = ?",
    "params": ["S"]
  }'
```

### Resposta

```json
{
  "success": true,
  "rowCount": 10,
  "data": [
    {
      "COD_PRODUTO": "100001",
      "DESCRICAO": "Produto Exemplo",
      "PRECO": 99.90
    }
  ],
  "executionTime": "18ms"
}
```

### Health Check (GET /health)

```bash
curl https://sua-api.com/health
```

```json
{
  "status": "healthy",
  "timestamp": "2025-01-02T10:00:00.000Z",
  "firebird": "connected",
  "pool": "active",
  "poolSize": 2,
  "poolAvailable": 2,
  "poolPending": 0
}
```

## 🔧 Integração com n8n

### Configuração do HTTP Request Node

1. **Method**: POST
2. **URL**: `https://sua-api.com/query`
3. **Authentication**:
   - Type: Generic Credential Type
   - **Header Auth**
   - Name: `x-api-key`
   - Value: `sua-api-key-aqui`

### Body JSON

```json
{
  "sql": "SELECT * FROM CLIENTES WHERE CODIGO = ?",
  "params": [{{ $json.codigo_cliente }}]
}
```

### Acessando os Resultados

```javascript
// Número de registros retornados
{{ $json.rowCount }}

// Primeiro registro
{{ $json.data[0].NOME }}
{{ $json.data[0].EMAIL }}

// Iterar sobre todos os registros
{{ $json.data }}
```

### Exemplo Completo: Buscar Pedidos do Cliente

```json
{
  "sql": "SELECT PED.NUMERO, PED.DATA_EMISSAO, PED.VALOR_TOTAL, CLI.NOME FROM PEDIDOS PED INNER JOIN CLIENTES CLI ON PED.COD_CLIENTE = CLI.CODIGO WHERE CLI.EMAIL = ? ORDER BY PED.DATA_EMISSAO DESC",
  "params": ["{{ $json.email }}"]
}
```

## 🎓 Queries Comuns para ERP Millennium

> 📚 **[Guia Completo de Queries Firebird](FIREBIRD_QUERY_GUIDE.md)** - Documentação detalhada sobre Dialect 1, datas, booleanos e troubleshooting

### Consultar Produto por Código

```json
{
  "sql": "SELECT COD_PRODUTO, DESCRICAO1, REFERENCIA, PRECO FROM PRODUTOS WHERE COD_PRODUTO = ?",
  "params": ["100001"]
}
```

### Listar Pedidos do Dia

```json
{
  "sql": "SELECT NUMERO, DATA_EMISSAO, VALOR_TOTAL, STATUS FROM PEDIDOS WHERE CAST(DATA_EMISSAO AS DATE) = CURRENT_DATE ORDER BY NUMERO DESC",
  "params": []
}
```

### Buscar Cliente por Email

```json
{
  "sql": "SELECT CODIGO, NOME, EMAIL, TELEFONE, CIDADE FROM CLIENTES WHERE EMAIL = ?",
  "params": ["cliente@exemplo.com"]
}
```

### Estoque de Produto

```json
{
  "sql": "SELECT P.COD_PRODUTO, P.DESCRICAO1, E.QUANTIDADE, E.DEPOSITO FROM PRODUTOS P LEFT JOIN ESTOQUE E ON P.PRODUTO = E.PRODUTO WHERE P.COD_PRODUTO = ?",
  "params": ["100001"]
}
```

## 🐳 Deploy com Docker

### Docker Compose (Desenvolvimento)

```yaml
version: '3.8'

services:
  firebird-gateway:
    image: firebird-api-gateway:latest
    build: .
    ports:
      - "3030:3030"
    environment:
      - NODE_ENV=production
      - PORT=3030
      - API_KEY=${API_KEY}
      - FB_HOST=${FB_HOST}
      - FB_PORT=${FB_PORT:-3050}
      - FB_DATABASE=${FB_DATABASE}
      - FB_USER=${FB_USER}
      - FB_PASSWORD=${FB_PASSWORD}
      - POOL_MIN=2
      - POOL_MAX=10
      - BLOCK_DDL=true
      - ALLOW_WRITE_OPS=false
    restart: unless-stopped
```

### Docker Swarm (Produção)

```bash
# Inicialize o Swarm (se ainda não tiver)
docker swarm init

# Crie a network para o Traefik
docker network create --driver overlay network_public

# Deploy da stack
docker stack deploy -c docker-compose.yml firebird-gateway

# Verifique o status
docker stack ps firebird-gateway
```

O arquivo `docker-compose.yml` já vem configurado para:
- ✅ 2 réplicas com load balancing
- ✅ Integração com Traefik + SSL Let's Encrypt
- ✅ Health checks automáticos
- ✅ Graceful shutdown
- ✅ Zero downtime deployment

## 🔒 Segurança

### Operações Bloqueadas por Padrão

**DDL Destrutivas (BLOCK_DDL=true):**
- ❌ DROP TABLE/DATABASE/INDEX/VIEW/PROCEDURE
- ❌ TRUNCATE TABLE
- ❌ ALTER TABLE/DATABASE
- ❌ CREATE TABLE/DATABASE/INDEX

**DML de Escrita (ALLOW_WRITE_OPS=false):**
- ❌ UPDATE
- ❌ INSERT
- ❌ DELETE
- ❌ EXECUTE PROCEDURE/BLOCK

### Ativando Operações de Escrita

⚠️ **Use com cuidado em produção!**

```bash
# No arquivo .env
ALLOW_WRITE_OPS=true
```

### Rate Limiting

Por padrão: **100 requisições por minuto por IP**

Configure no `.env`:
```bash
RATE_LIMIT_WINDOW=60000  # 1 minuto
RATE_LIMIT_MAX=100       # Requisições permitidas
```

## 📊 Monitoramento

### Verificar Logs

```bash
# Docker Compose
docker-compose logs -f

# Docker Swarm
docker service logs -f firebird-gateway_firebird-gateway
```

### Verificar Status

```bash
# Docker Compose
docker-compose ps

# Docker Swarm
docker service ls
docker stack ps firebird-gateway
```

### Métricas no Health Check

O endpoint `/health` retorna:
- Status da conexão com Firebird
- Tamanho do pool de conexões
- Conexões disponíveis
- Conexões pendentes

## 🛠️ Troubleshooting

### Container não inicia

**Erro**: Container fica reiniciando

**Solução**: Verifique os logs para variáveis faltando:
```bash
docker-compose logs | grep "❌"
```

Certifique-se que estas variáveis estão no `.env`:
- `API_KEY`
- `FB_HOST`
- `FB_DATABASE`
- `FB_USER`
- `FB_PASSWORD`

### Erro 401 Unauthorized

**Solução**: Confirme que o header `x-api-key` está correto:
```bash
curl -H "x-api-key: sua-chave" https://sua-api.com/health
```

### Erro de conexão com Firebird

**Soluções**:
1. Teste conectividade: `telnet seu-firebird-host 3050`
2. Verifique credenciais no `.env`
3. Confirme que o caminho do banco está correto (absoluto)

### Queries lentas

**Soluções**:
1. Aumente o pool: `POOL_MAX=20`
2. Crie índices nas tabelas Firebird
3. Otimize a query SQL
4. Aumente recursos do container

## 📚 Estrutura do Projeto

```
firebird-api/
├── server.js              # Aplicação Express + Pool Firebird
├── package.json           # Dependências (node-firebird-driver-native)
├── Dockerfile             # Imagem Debian Slim + libfbclient2
├── docker-compose.yml     # Stack Docker Swarm + Traefik
├── .env.example           # Template de variáveis
├── .dockerignore          # Otimização do build
├── build.sh               # Script de build automático
├── deploy.sh              # Script de deploy automático
├── test.sh                # Suite de testes
├── FIREBIRD_QUERY_GUIDE.md # 📚 Guia completo de queries Dialect 1
├── QUICK_START.md         # Guia rápido de deploy
├── claude.md              # Documentação técnica interna
└── README.md              # Esta documentação
```

## 🧪 Testes

```bash
# Executar suite de testes
chmod +x test.sh
./test.sh http://localhost:3030 sua-api-key

# Teste manual rápido
curl http://localhost:3030/health
```

## 🔄 Atualizações

### Atualizar a Aplicação

```bash
# 1. Faça as alterações no código
# 2. Rebuild
docker-compose build

# 3. Reinicie (zero downtime no Swarm)
docker-compose up -d
```

### Rollback (Swarm)

```bash
docker service rollback firebird-gateway_firebird-gateway
```

## 📝 Changelog

### v2.1.0 (2025-01-02)
- ✅ **Resultados como objetos JSON** com nomes de colunas usando `fetchAsObject()`
- ✅ Simplificado código (removida conversão manual de metadata)
- ✅ Corrigidos bugs de lifecycle de transações
- ✅ Melhor integração com n8n e Make.com

### v2.0.0 (2024-12-26)
- ✅ Migração para `node-firebird-driver-native` v3.2.2
- ✅ Suporte automático a WireCrypt (Firebird 3.0+)
- ✅ Pool de conexões com `generic-pool`
- ✅ Dockerfile migrado de Alpine para Debian (libfbclient2)

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:
1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/MinhaFeature`)
3. Commit suas mudanças (`git commit -m 'Adiciona MinhaFeature'`)
4. Push para a branch (`git push origin feature/MinhaFeature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

## 💬 Suporte

- 📖 [Documentação do Firebird](https://firebirdsql.org/en/documentation/)
- 🔧 [Issues do GitHub](https://github.com/seu-usuario/firebird-rest-api/issues)
- 💡 [Documentação do n8n](https://docs.n8n.io/)

## ⭐ Agradecimentos

Desenvolvido para facilitar a integração de ERPs Firebird (Millennium, Sankhya, Dealer, etc.) com ferramentas modernas de automação.

Se este projeto foi útil para você, considere dar uma ⭐ no repositório!

---

**Feito com ❤️ para a comunidade Firebird e n8n**
