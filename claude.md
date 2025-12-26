# Projeto: Gateway REST API Firebird para n8n

## Contexto
Gateway REST API em Node.js que permite ao n8n executar queries SQL no Firebird do ERP Millennium.

## Infraestrutura
- Docker Swarm em produção com Traefik
- Firebird: [SEU_HOST]:3050
- Database: /caminho/para/seu/banco.fdb
- n8n remoto consumindo via HTTPS
- URL: https://sua-api.com

## Requisitos Principais
1. Endpoint genérico `/query` (POST) - aceita qualquer SQL
2. Pool de conexões Firebird
3. Autenticação via header `x-api-key`
4. Rate limiting
5. Health check `/health`
6. Logs de auditoria
7. Graceful shutdown

## Segurança
- Bloquear DDL destrutivas (DROP, TRUNCATE, ALTER) - OBRIGATÓRIO
- Controle de UPDATE/INSERT via variável de ambiente (ativável)
- Helmet.js para headers
- Validação de inputs

## Deploy
- Docker Swarm stack com 2+ réplicas
- Labels Traefik para SSL Let's Encrypt
- Network: network_public
- Secrets no stack

## Status Implementação
- [x] Estrutura básica do projeto
- [x] Server.js com pool de conexões
- [x] Docker setup completo
- [x] Testes e validação

## Arquivos Criados
1. ✅ package.json - Dependências do projeto
2. ✅ server.js - Gateway REST API completo
3. ✅ Dockerfile - Containerização com Alpine Linux
4. ✅ docker-compose.yml - Stack do Swarm com Traefik
5. ✅ .env.example - Variáveis vazias (obriga preenchimento)
6. ✅ .env.production.example - Exemplo completo com valores
7. ✅ build.sh - Script automático de build da imagem
8. ✅ deploy.sh - Script automático de deploy no Swarm
9. ✅ test.sh - Suite de testes automatizados
10. ✅ README.md - Documentação completa
11. ✅ .dockerignore - Otimização do build
12. ✅ .gitignore - Controle de versão

## Melhorias de Segurança Implementadas (v3)
- ✅ **SEM valores padrão hardcoded no server.js** - Servidor falha se .env não tiver configurações
- ✅ **docker-compose.yml usa variáveis do .env** - Zero hardcoding de credenciais
- ✅ **deploy.sh exporta variáveis do .env** - Solução para Docker Swarm (env_file não funciona)
- ✅ **Validação obrigatória** no startup de: API_KEY, FB_HOST, FB_DATABASE, FB_USER, FB_PASSWORD
- ✅ **.env.example vazio** - Força preenchimento manual (segurança)
- ✅ **.env.production.example** - Arquivo de referência com valores de exemplo
- ✅ **Porta atualizada para 3030** - Sincronizada em todo o projeto
- ✅ Mensagens de erro claras indicando variáveis faltantes
- ✅ Proteção contra conexões acidentais em ambientes errados

## Importante sobre Docker Swarm
- `env_file:` NÃO funciona com `docker stack deploy` (apenas com docker-compose up)
- Solução: deploy.sh usa `set -a` + `source .env` para exportar variáveis antes do deploy
- As variáveis exportadas são substituídas em ${VAR} no docker-compose.yml

## Importante sobre Firebird 3.0+ WireCrypt
- Firebird 3.0+ tem recurso de criptografia de comunicação (WireCrypt)
- Erro "Incompatible wire encryption levels" ocorre quando cliente e servidor têm configurações diferentes
- **SOLUÇÃO IMPLEMENTADA**: Migração completa para `node-firebird-driver-native` v3.2.2 (latest)
- A biblioteca antiga `node-firebird` tinha suporte limitado ao WireCrypt
- `node-firebird-driver-native` é moderna (Firebird 3+, Node.js 18+) e gerencia WireCrypt automaticamente
- Não é mais necessária configuração manual de WireCrypt - a biblioteca nativa lida com isso internamente

## Scripts de Automação
### build.sh
- Build automático da imagem Docker
- Validações pré-build (Dockerfile, package.json)
- Suporte a registry (push opcional)
- Exibe tamanho da imagem e próximos passos

### deploy.sh
- Deploy completo e automático no Swarm
- Validações: Swarm ativo, .env existe, variáveis obrigatórias
- Cria network_public se não existir
- Build automático da imagem (opcional: --no-build)
- Remove stack (--remove)
- Mostra comandos úteis após deploy

### test.sh
- Suite de testes completa
- 6 testes: health check, autenticação, queries, proteções DDL/DML
- Relatório colorido e detalhado

## Migração para v2.0 - node-firebird-driver-native

### Problema Resolvido: WireCrypt Incompatibility
- **Erro original**: "Incompatible wire encryption levels requested on client and server" (gdscode: 335545064)
- **Causa**: Biblioteca `node-firebird` v1.1.8 tinha suporte limitado ao WireCrypt do Firebird 3.0+
- **Restrição**: Não podemos modificar o servidor Firebird (ERP em produção, outras aplicações funcionam)
- **Solução**: Migração completa para `node-firebird-driver-native` v3.2.2

### Mudanças Implementadas (v2.0)

#### 1. Dependencies (package.json)
- ✅ Removido: `node-firebird: ^1.1.8`
- ✅ Adicionado: `node-firebird-driver-native: ^3.2.2` (versão atual/latest)
- ✅ Adicionado: `generic-pool: ^3.9.0` (para pool de conexões)

#### 2. Server.js - Reescrita Completa
- ✅ **Novo padrão**: async/await em vez de callbacks
- ✅ **Cliente nativo**: `createNativeClient(getDefaultLibraryFilename())`
- ✅ **Conexão**: `client.connect(connectionString, { username, password })`
- ✅ **Pool customizado**: Implementado com `generic-pool`
- ✅ **Connection factory**: create, destroy, validate
- ✅ **Transações**: `attachment.startTransaction()`, commit/rollback automático
- ✅ **Prepared statements**: Para queries com parâmetros
- ✅ **Graceful shutdown**: `pool.drain()`, `pool.clear()`, `client.dispose()`
- ✅ **Health check melhorado**: Mostra poolSize, poolAvailable, poolPending
- ✅ **Version**: 2.0.0

#### 3. Configuração
- ✅ Removida variável `FB_WIRE_CRYPT` (.env.example, docker-compose.yml)
- ✅ WireCrypt agora é gerenciado automaticamente pela biblioteca nativa
- ✅ Connection string: formato `host:database` ou `host/port:database`
- ✅ Healthcheck start_period: 60s (tempo para inicialização do native client)

#### 4. Dockerfile - Mudança Crítica: Alpine → Debian
- ✅ **Mudado de**: `node:18-alpine` (musl libc)
- ✅ **Mudado para**: `node:18-slim` (glibc - Debian)
- ✅ **Motivo**: Alpine não tem pacotes nativos do Firebird client
- ✅ **Instalado**: `libfbclient2` (biblioteca cliente Firebird - ESSENCIAL)
- ✅ Comandos de usuário adaptados para Debian (`groupadd` / `useradd` vs `addgroup` / `adduser`)
- ⚠️ **Imagem maior**: ~200MB (Debian) vs ~150MB (Alpine), mas é necessário para Firebird

#### 5. Features Mantidas
- ✅ Validação de ambiente obrigatória
- ✅ SQL validation (DDL blocking, DML blocking)
- ✅ API Key authentication
- ✅ Rate limiting
- ✅ Audit logging
- ✅ Graceful shutdown
- ✅ Zero hardcoded values

### Benefícios da Migração
- ✅ **WireCrypt automático**: Biblioteca nativa gerencia criptografia transparentemente
- ✅ **Firebird 3+ nativo**: Suporte completo a recursos modernos via libfbclient2
- ✅ **TypeScript ready**: Biblioteca tem tipos nativos
- ✅ **Async/await**: Código mais limpo e moderno
- ✅ **Melhor error handling**: Transações com rollback automático
- ✅ **Pool robusto**: generic-pool é battle-tested

### Desafios Resolvidos

#### Desafio 1: WireCrypt Incompatibility
- **Erro**: "Incompatible wire encryption levels requested on client and server"
- **Solução**: Migração para `node-firebird-driver-native` v3.2.2

#### Desafio 2: Missing libfbclient.so
- **Erro**: "Cannot load Firebird client library: 'libfbclient.so'"
- **Causa**: Alpine Linux não tem pacotes Firebird (musl libc vs glibc)
- **Solução**: Migração do Dockerfile de `node:18-alpine` para `node:18-slim` (Debian)
- **Pacote instalado**: `libfbclient2` (biblioteca cliente oficial do Firebird)

## Melhorias v2.1 - Formatação de Resultados com fetchAsObject()

### Problema: Resultados vinham como Arrays
Antes os resultados vinham como arrays de valores sem nomes de colunas:
```json
{
  "data": [[1713, "CI222466", "VESTIDO", ...]]
}
```

### Tentativa Inicial (FALHOU)
Primeira tentativa foi criar função `convertRowsToMetadata()` que:
- Tentava ler `resultSet.metadata` para pegar nomes das colunas
- **PROBLEMA**: `resultSet.metadata` é `undefined` no `node-firebird-driver-native`
- Resultava em erro "Transaction is already committed or rolled back"

### Solução Final: fetchAsObject() Nativo
Descoberto que a biblioteca `node-firebird-driver-native` tem método nativo:
- **`resultSet.fetchAsObject()`** - retorna objetos JSON diretamente
- Não precisa de conversão manual ou acesso a metadata
- Método nativo, mais performático e confiável

#### Mudanças Implementadas
1. ✅ **Removida** função `convertRowsToMetadata()` (desnecessária)
2. ✅ **Substituído** `resultSet.fetch()` por `resultSet.fetchAsObject()`
3. ✅ **Simplificado** código - muito mais limpo
4. ✅ **Corrigidos** bugs de rollback e lifecycle de transações
5. ✅ **Versão atualizada** para 2.1.0

#### Antes (server.js - ERRADO)
```javascript
const resultSet = await statement.executeQuery(transaction, params);
const rows = await resultSet.fetch(); // Retorna arrays
const metadata = resultSet.metadata; // undefined!
await resultSet.close();
const result = convertRowsToMetadata(metadata, rows); // Quebrava aqui
await transaction.commit();
return result;
```

#### Depois (server.js - CORRETO)
```javascript
const resultSet = await statement.executeQuery(transaction, params);
const rows = await resultSet.fetchAsObject(); // Retorna objetos JSON!
await resultSet.close();
await statement.commit();
return rows;
```

### Resultado
Agora retorna objetos JSON com nomes de colunas:
```json
{
  "success": true,
  "rowCount": 2,
  "data": [
    {
      "PRODUTO": 1713,
      "COD_PRODUTO": "100001",
      "REFERENCIA": "CI222466",
      "DESCRICAO1": "COL. 34LD - VESTIDO CURTO CARLOTA CI222466",
      "DESCRICAO2": "VESTIDO",
      "DATA_ATUALIZACAO": "2025-01-02T09:36:39.794Z",
      ...
    }
  ],
  "executionTime": "21ms"
}
```

### Benefícios
- ✅ **Mais simples**: 4 linhas vs 10+ linhas de código
- ✅ **Mais rápido**: Método nativo otimizado
- ✅ **Mais confiável**: Sem manipulação manual de metadata
- ✅ **Menos bugs**: Lifecycle de transação correto
- ✅ **Melhor para n8n**: Acesso direto a campos `$json.data[0].COD_PRODUTO`

## Status Final - PRODUÇÃO
✅ **API Firebird Gateway v2.1 - FUNCIONANDO EM PRODUÇÃO**
- URL: https://sua-api.com
- 2 réplicas no Docker Swarm
- SSL via Traefik + Let's Encrypt
- Pool de conexões: 2-10
- Firebird 3.0+ com WireCrypt automático
- **Resultados formatados como objetos JSON usando fetchAsObject()**
- Integrado com n8n
- Pronto para uso em produção

## Dados Sensíveis
⚠️ **IMPORTANTE**: Este arquivo claude.md é apenas para referência técnica. Não commite dados sensíveis:
- Remova URLs, IPs e portas específicas do servidor
- Remova credenciais SSH, senhas, API Keys
- Use exemplos genéricos no lugar
