#!/bin/bash

# ============================================================================
# Script de Teste do Firebird API Gateway
# ============================================================================
# Testa os principais endpoints da API
#
# Uso:
#   ./test.sh [URL] [API_KEY]
#
# Exemplos:
#   ./test.sh http://localhost:3030 minha-api-key
#   ./test.sh https://api.seudominio.com.br minha-api-key
#

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuração
API_URL=${1:-"http://localhost:3000"}
API_KEY=${2:-""}

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Firebird API Gateway - Suite de Testes${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "URL: ${YELLOW}${API_URL}${NC}"
echo -e "API Key: ${YELLOW}${API_KEY:0:10}...${NC}"
echo ""

# Verifica se API_KEY foi fornecida
if [ -z "$API_KEY" ]; then
    echo -e "${RED}❌ ERRO: API_KEY não fornecida${NC}"
    echo ""
    echo "Uso: $0 [URL] [API_KEY]"
    echo "Exemplo: $0 http://localhost:3000 minha-api-key"
    echo ""
    exit 1
fi

# ============================================================================
# TESTE 1: Health Check
# ============================================================================
echo -e "${BLUE}[1/6]${NC} Testando Health Check..."

RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/health")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Health Check OK${NC}"
    echo -e "   Status: $(echo $BODY | grep -o '"status":"[^"]*"' | cut -d'"' -f4)"
else
    echo -e "${RED}❌ Health Check FALHOU (HTTP $HTTP_CODE)${NC}"
    echo -e "   Response: $BODY"
    exit 1
fi
echo ""

# ============================================================================
# TESTE 2: Endpoint Raiz (Info da API)
# ============================================================================
echo -e "${BLUE}[2/6]${NC} Testando endpoint raiz (/)..."

RESPONSE=$(curl -s -w "\n%{http_code}" "${API_URL}/")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Endpoint raiz OK${NC}"
    echo -e "   $(echo $BODY | grep -o '"service":"[^"]*"')"
else
    echo -e "${RED}❌ Endpoint raiz FALHOU (HTTP $HTTP_CODE)${NC}"
fi
echo ""

# ============================================================================
# TESTE 3: Query sem autenticação (deve falhar)
# ============================================================================
echo -e "${BLUE}[3/6]${NC} Testando query SEM autenticação (deve retornar 401)..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT 1 FROM RDB$DATABASE"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" == "401" ]; then
    echo -e "${GREEN}✅ Autenticação funcionando (401 Unauthorized)${NC}"
else
    echo -e "${YELLOW}⚠️  Esperado 401, recebido HTTP $HTTP_CODE${NC}"
fi
echo ""

# ============================================================================
# TESTE 4: Query válida com autenticação
# ============================================================================
echo -e "${BLUE}[4/6]${NC} Testando query válida COM autenticação..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"sql":"SELECT 1 AS TESTE FROM RDB$DATABASE"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "200" ]; then
    SUCCESS=$(echo $BODY | grep -o '"success":true')
    if [ ! -z "$SUCCESS" ]; then
        echo -e "${GREEN}✅ Query executada com sucesso${NC}"
        echo -e "   Row Count: $(echo $BODY | grep -o '"rowCount":[0-9]*' | cut -d':' -f2)"
        echo -e "   Execution Time: $(echo $BODY | grep -o '"executionTime":"[^"]*"' | cut -d'"' -f4)"
    else
        echo -e "${RED}❌ Query falhou${NC}"
        echo -e "   Response: $BODY"
    fi
else
    echo -e "${RED}❌ Query FALHOU (HTTP $HTTP_CODE)${NC}"
    echo -e "   Response: $BODY"
fi
echo ""

# ============================================================================
# TESTE 5: Proteção contra DDL (DROP)
# ============================================================================
echo -e "${BLUE}[5/6]${NC} Testando proteção contra DDL (DROP TABLE)..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"sql":"DROP TABLE teste"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "400" ]; then
    echo -e "${GREEN}✅ Proteção DDL funcionando (bloqueou DROP)${NC}"
    echo -e "   $(echo $BODY | grep -o '"error":"[^"]*"' | cut -d'"' -f4)"
else
    echo -e "${YELLOW}⚠️  Esperado 400, recebido HTTP $HTTP_CODE${NC}"
    echo -e "   Response: $BODY"
fi
echo ""

# ============================================================================
# TESTE 6: Proteção contra operações de escrita (se ALLOW_WRITE_OPS=false)
# ============================================================================
echo -e "${BLUE}[6/6]${NC} Testando proteção contra UPDATE (se ALLOW_WRITE_OPS=false)..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -H "x-api-key: ${API_KEY}" \
  -d '{"sql":"UPDATE teste SET campo = 1"}')

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" == "400" ]; then
    echo -e "${GREEN}✅ Proteção UPDATE funcionando (bloqueou UPDATE)${NC}"
    echo -e "   $(echo $BODY | grep -o '"error":"[^"]*"' | cut -d'"' -f4)"
elif [ "$HTTP_CODE" == "500" ]; then
    echo -e "${YELLOW}⚠️  UPDATE permitido mas falhou (tabela não existe)${NC}"
    echo -e "   Nota: ALLOW_WRITE_OPS pode estar habilitado"
else
    echo -e "${YELLOW}⚠️  Resposta inesperada: HTTP $HTTP_CODE${NC}"
    echo -e "   Response: $BODY"
fi
echo ""

# ============================================================================
# RESUMO
# ============================================================================
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Testes concluídos!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Próximos passos:"
echo -e "  1. Verifique os logs do container: ${YELLOW}docker service logs -f <service-name>${NC}"
echo -e "  2. Teste queries reais do seu banco Firebird"
echo -e "  3. Configure o n8n para usar a API"
echo ""
