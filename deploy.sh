#!/bin/bash

# ============================================================================
# Script de Deploy Completo - Firebird API Gateway
# ============================================================================
# Faz build, validações e deploy no Docker Swarm
#
# Uso:
#   ./deploy.sh                # Deploy completo (build + deploy)
#   ./deploy.sh --no-build     # Apenas deploy (sem build)
#   ./deploy.sh --remove       # Remove a stack
#

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
STACK_NAME="firebird-gateway"
COMPOSE_FILE="docker-compose.yml"
IMAGE_NAME="firebird-api-gateway"

# Parse argumentos
DO_BUILD=true
DO_REMOVE=false

for arg in "$@"; do
    case $arg in
        --no-build)
            DO_BUILD=false
            ;;
        --remove)
            DO_REMOVE=true
            ;;
    esac
done

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Firebird API Gateway - Deploy Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ============================================================================
# MODO REMOÇÃO
# ============================================================================

if [ "$DO_REMOVE" = true ]; then
    echo -e "${YELLOW}Removendo stack: ${STACK_NAME}${NC}"
    echo ""

    docker stack rm "${STACK_NAME}"

    echo ""
    echo -e "${GREEN}✅ Stack removida!${NC}"
    echo ""
    echo "Aguarde alguns segundos para os containers serem completamente removidos."
    echo "Verifique com: docker stack ps ${STACK_NAME}"
    echo ""
    exit 0
fi

# ============================================================================
# VALIDAÇÕES PRÉ-DEPLOY
# ============================================================================

echo -e "${BLUE}[1/6]${NC} Validando ambiente..."
echo ""

# Verifica se está no Swarm mode
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${RED}❌ Docker Swarm não está ativo!${NC}"
    echo ""
    echo "Inicialize o Swarm com:"
    echo "  docker swarm init"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Docker Swarm ativo${NC}"

# Verifica se docker-compose.yml existe
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}❌ Arquivo ${COMPOSE_FILE} não encontrado!${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Arquivo ${COMPOSE_FILE} encontrado${NC}"

# Verifica se .env existe
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ Arquivo .env não encontrado!${NC}"
    echo ""
    echo "Crie o arquivo .env:"
    echo "  cp .env.example .env"
    echo "  nano .env"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Arquivo .env encontrado${NC}"

# Valida e EXPORTA variáveis obrigatórias do .env
echo ""
echo -e "Validando e exportando variáveis obrigatórias..."

# Carrega e exporta todas as variáveis do .env
set -a  # Exporta automaticamente todas as variáveis
source .env
set +a

REQUIRED_VARS=("API_KEY" "FB_HOST" "FB_DATABASE" "FB_USER" "FB_PASSWORD" "DOMAIN")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}❌ Variáveis obrigatórias faltando no .env:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "  ${RED}❌ $var${NC}"
    done
    echo ""
    echo "Edite o arquivo .env e preencha todas as variáveis obrigatórias."
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Todas variáveis obrigatórias configuradas e exportadas${NC}"

# Verifica se network existe
if ! docker network ls | grep -q "network_public"; then
    echo -e "${YELLOW}⚠️  Network 'network_public' não existe${NC}"
    echo ""
    echo "Criando network..."
    docker network create --driver overlay network_public
    echo -e "${GREEN}✅ Network criada${NC}"
else
    echo -e "${GREEN}✅ Network 'network_public' existe${NC}"
fi

echo ""

# ============================================================================
# BUILD DA IMAGEM (se necessário)
# ============================================================================

if [ "$DO_BUILD" = true ]; then
    echo -e "${BLUE}[2/6]${NC} Fazendo build da imagem..."
    echo ""

    if [ -f "build.sh" ]; then
        chmod +x build.sh
        ./build.sh
    else
        echo "Fazendo build manual..."
        docker build -t "${IMAGE_NAME}:latest" .
    fi

    echo ""
else
    echo -e "${BLUE}[2/6]${NC} Build ${YELLOW}pulado${NC} (--no-build especificado)"
    echo ""

    # Verifica se imagem existe
    if ! docker image inspect "${IMAGE_NAME}:latest" > /dev/null 2>&1; then
        echo -e "${RED}❌ Imagem ${IMAGE_NAME}:latest não encontrada!${NC}"
        echo ""
        echo "Execute o build primeiro ou remova --no-build"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}✅ Imagem ${IMAGE_NAME}:latest encontrada${NC}"
    echo ""
fi

# ============================================================================
# DEPLOY NO SWARM
# ============================================================================

echo -e "${BLUE}[3/6]${NC} Fazendo deploy no Swarm..."
echo ""

echo -e "Stack: ${YELLOW}${STACK_NAME}${NC}"
echo -e "Compose: ${YELLOW}${COMPOSE_FILE}${NC}"
echo ""

docker stack deploy -c "${COMPOSE_FILE}" "${STACK_NAME}"

echo ""
echo -e "${GREEN}✅ Deploy iniciado!${NC}"
echo ""

# ============================================================================
# AGUARDA INICIALIZAÇÃO
# ============================================================================

echo -e "${BLUE}[4/6]${NC} Aguardando containers iniciarem..."
echo ""

sleep 5

# ============================================================================
# VERIFICA STATUS
# ============================================================================

echo -e "${BLUE}[5/6]${NC} Verificando status..."
echo ""

docker stack ps "${STACK_NAME}" --no-trunc

echo ""

# Conta réplicas em execução
RUNNING=$(docker stack ps "${STACK_NAME}" --filter "desired-state=running" -q 2>/dev/null | wc -l | xargs)

if [ "$RUNNING" -gt 0 ]; then
    echo -e "${GREEN}✅ ${RUNNING} réplica(s) em execução${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhuma réplica em execução ainda${NC}"
    echo "Aguarde alguns segundos e verifique os logs."
fi

echo ""

# ============================================================================
# INFORMAÇÕES ÚTEIS
# ============================================================================

echo -e "${BLUE}[6/6]${NC} Informações úteis:"
echo ""

echo -e "${BLUE}Comandos de monitoramento:${NC}"
echo ""
echo -e "Ver status da stack:"
echo -e "  ${YELLOW}docker stack ps ${STACK_NAME}${NC}"
echo ""
echo -e "Ver logs (tempo real):"
echo -e "  ${YELLOW}docker service logs -f ${STACK_NAME}_firebird-gateway${NC}"
echo ""
echo -e "Ver logs (últimas 100 linhas):"
echo -e "  ${YELLOW}docker service logs --tail 100 ${STACK_NAME}_firebird-gateway${NC}"
echo ""
echo -e "Listar serviços:"
echo -e "  ${YELLOW}docker service ls${NC}"
echo ""
echo -e "Inspecionar serviço:"
echo -e "  ${YELLOW}docker service inspect ${STACK_NAME}_firebird-gateway${NC}"
echo ""

echo -e "${BLUE}Comandos de administração:${NC}"
echo ""
echo -e "Escalar serviço:"
echo -e "  ${YELLOW}docker service scale ${STACK_NAME}_firebird-gateway=3${NC}"
echo ""
echo -e "Atualizar serviço:"
echo -e "  ${YELLOW}./deploy.sh${NC}"
echo ""
echo -e "Remover stack:"
echo -e "  ${YELLOW}./deploy.sh --remove${NC}"
echo ""

# ============================================================================
# RESUMO
# ============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Deploy concluído!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Aguarde alguns segundos para os containers ficarem saudáveis."
echo ""
echo -e "Teste o health check:"
echo -e "  ${YELLOW}curl https://${DOMAIN}/health${NC}"
echo ""
echo -e "Execute os testes completos:"
echo -e "  ${YELLOW}./test.sh https://${DOMAIN} sua-api-key${NC}"
echo ""
