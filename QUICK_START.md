# Quick Start - Firebird API Gateway

Guia rápido para deploy usando os scripts de automação.

## 📋 Pré-requisitos

- Docker Swarm ativo
- Traefik configurado com network `network_public`
- Acesso ao servidor Firebird

## 🚀 Deploy em 3 Passos

### 1️⃣ Configure o ambiente

```bash
# Copie o arquivo de exemplo
cp .env.example .env

# Gere uma API Key forte
openssl rand -hex 32

# Edite o .env e preencha TODAS as variáveis obrigatórias
nano .env
```

**Variáveis obrigatórias no .env:**
- `API_KEY` - Chave de autenticação (use a gerada acima)
- `DOMAIN` - Domínio público da API (ex: api.meudominio.com.br)
- `FB_HOST` - IP do Firebird (ex: 192.168.1.10)
- `FB_DATABASE` - Caminho do banco (ex: /caminho/para/banco.fdb)
- `FB_USER` - Usuário (ex: SYSDBA)
- `FB_PASSWORD` - Senha do banco

### 3️⃣ Deploy!

```bash
# Torne os scripts executáveis
chmod +x *.sh

# Deploy completo (build + deploy + validações)
./deploy.sh
```

Pronto! 🎉

## ✅ Validar o Deploy

```bash
# Teste o health check
curl https://seu-dominio.com.br/health

# Execute a suite de testes completa
./test.sh https://seu-dominio.com.br sua-api-key
```

## 📊 Monitoramento

```bash
# Ver status da stack
docker stack ps firebird-gateway

# Ver logs em tempo real
docker service logs -f firebird-gateway_firebird-gateway

# Ver logs (últimas 100 linhas)
docker service logs --tail 100 firebird-gateway_firebird-gateway
```

## 🔄 Atualizar o Serviço

```bash
# Faça alterações no código e execute
./deploy.sh

# Ou apenas rebuild sem deploy
./build.sh
./deploy.sh --no-build
```

## 🗑️ Remover o Serviço

```bash
./deploy.sh --remove
```

## 🆘 Troubleshooting Rápido

### Container não inicia?

```bash
# Veja os logs - vai mostrar o que está faltando
docker service logs firebird-gateway_firebird-gateway
```

Provavelmente você verá:
```
❌ ERRO: Variáveis de ambiente faltando!
  ❌ API_KEY
  ❌ FB_HOST
```

**Solução**: Preencha o `.env` corretamente.

### Erro de conexão com Firebird?

```bash
# Teste conectividade (use o IP do seu Firebird)
ping SEU_IP_FIREBIRD
telnet SEU_IP_FIREBIRD 3050
```

**Solução**: Verifique IP, porta e credenciais no `.env`.

### Queries sendo bloqueadas?

Se você precisa permitir UPDATE/INSERT/DELETE:

```bash
# Edite o .env
ALLOW_WRITE_OPS=true

# Redeploy
./deploy.sh
```

## 📚 Documentação Completa

Para mais detalhes, veja o [README.md](README.md) completo.

---

**Desenvolvido para integração n8n + Firebird ERP Millennium**
