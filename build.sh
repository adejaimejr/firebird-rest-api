#!/bin/bash

# ============================================================================
# Script de Build da Imagem Docker - Firebird API Gateway
# ============================================================================
# Faz o build da imagem Docker localmente ou para registry
#
# Uso:
#   ./build.sh                    # Build local apenas
#   ./build.sh push               # Build e push para registry
#   ./build.sh push custom-tag    # Build com tag customizada
#

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
IMAGE_NAME="firebird-api-gateway"
VERSION="latest"
REGISTRY="${DOCKER_REGISTRY:-}"  # Opcional: defina DOCKER_REGISTRY no .env ou aqui

# Parse argumentos
PUSH_TO_REGISTRY=false
if [ "$1" == "push" ]; then
    PUSH_TO_REGISTRY=true
    if [ ! -z "$2" ]; then
        VERSION="$2"
    fi
fi

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Firebird API Gateway - Build Script${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ============================================================================
# VALIDAÇÕES
# ============================================================================

echo -e "${BLUE}[1/5]${NC} Validando ambiente..."

# Verifica se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker não está rodando!${NC}"
    echo ""
    exit 1
fi

# Verifica se Dockerfile existe
if [ ! -f "Dockerfile" ]; then
    echo -e "${RED}❌ Dockerfile não encontrado!${NC}"
    echo "Execute este script no diretório raiz do projeto."
    echo ""
    exit 1
fi

# Verifica se package.json existe
if [ ! -f "package.json" ]; then
    echo -e "${RED}❌ package.json não encontrado!${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ Ambiente validado${NC}"
echo ""

# ============================================================================
# BUILD DA IMAGEM
# ============================================================================

echo -e "${BLUE}[2/5]${NC} Fazendo build da imagem Docker..."
echo ""

# Define o nome completo da imagem
if [ ! -z "$REGISTRY" ]; then
    FULL_IMAGE_NAME="${REGISTRY}/${IMAGE_NAME}:${VERSION}"
    echo -e "Registry: ${YELLOW}${REGISTRY}${NC}"
else
    FULL_IMAGE_NAME="${IMAGE_NAME}:${VERSION}"
fi

echo -e "Imagem: ${YELLOW}${FULL_IMAGE_NAME}${NC}"
echo ""

# Build
docker build \
    --tag "${FULL_IMAGE_NAME}" \
    --tag "${IMAGE_NAME}:latest" \
    --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
    --build-arg VERSION="${VERSION}" \
    .

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ Build concluído com sucesso!${NC}"
else
    echo ""
    echo -e "${RED}❌ Erro no build!${NC}"
    exit 1
fi

echo ""

# ============================================================================
# INFORMAÇÕES DA IMAGEM
# ============================================================================

echo -e "${BLUE}[3/5]${NC} Informações da imagem..."
echo ""

IMAGE_SIZE=$(docker images "${FULL_IMAGE_NAME}" --format "{{.Size}}")
echo -e "Tamanho: ${YELLOW}${IMAGE_SIZE}${NC}"

echo ""

# ============================================================================
# TESTE BÁSICO
# ============================================================================

echo -e "${BLUE}[4/5]${NC} Testando imagem (verificação básica)..."
echo ""

# Testa se a imagem foi criada corretamente
if docker image inspect "${FULL_IMAGE_NAME}" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Imagem criada com sucesso${NC}"
else
    echo -e "${RED}❌ Imagem não foi criada corretamente${NC}"
    exit 1
fi

echo ""

# ============================================================================
# PUSH PARA REGISTRY (opcional)
# ============================================================================

if [ "$PUSH_TO_REGISTRY" = true ]; then
    echo -e "${BLUE}[5/5]${NC} Fazendo push para registry..."
    echo ""

    if [ -z "$REGISTRY" ]; then
        echo -e "${RED}❌ Registry não configurado!${NC}"
        echo "Configure a variável DOCKER_REGISTRY ou edite o script."
        echo ""
        exit 1
    fi

    echo -e "Enviando para: ${YELLOW}${REGISTRY}${NC}"
    echo ""

    docker push "${FULL_IMAGE_NAME}"

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✅ Push concluído com sucesso!${NC}"
    else
        echo ""
        echo -e "${RED}❌ Erro no push!${NC}"
        exit 1
    fi
else
    echo -e "${BLUE}[5/5]${NC} Push para registry ${YELLOW}pulado${NC} (use './build.sh push' para enviar)"
fi

echo ""

# ============================================================================
# RESUMO
# ============================================================================

echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✅ Build concluído!${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Imagem criada:"
echo -e "  ${YELLOW}${FULL_IMAGE_NAME}${NC}"
echo -e "  ${YELLOW}${IMAGE_NAME}:latest${NC}"
echo ""
echo -e "Tamanho: ${YELLOW}${IMAGE_SIZE}${NC}"
echo ""

if [ "$PUSH_TO_REGISTRY" = true ]; then
    echo -e "Status: ${GREEN}Build + Push completos${NC}"
    echo ""
    echo -e "Deploy no Swarm:"
    echo -e "  ${YELLOW}docker stack deploy -c docker-compose.yml firebird-gateway${NC}"
else
    echo -e "Próximos passos:"
    echo ""
    echo -e "1. Testar localmente (opcional):"
    echo -e "   ${YELLOW}docker run --rm --env-file .env -p 3030:3030 ${IMAGE_NAME}:latest${NC}"
    echo ""
    echo -e "2. Push para registry (se necessário):"
    echo -e "   ${YELLOW}./build.sh push${NC}"
    echo ""
    echo -e "3. Deploy no Swarm:"
    echo -e "   ${YELLOW}docker stack deploy -c docker-compose.yml firebird-gateway${NC}"
fi

echo ""
