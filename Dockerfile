# Imagem base oficial do Node.js 18 LTS (Debian Slim para suporte Firebird)
# Nota: Alpine não tem suporte nativo ao Firebird client (libfbclient.so)
FROM node:18-slim

# Metadados
LABEL maintainer="Transby Shop"
LABEL description="Gateway REST API para Firebird - n8n Integration v2.0"

# Criar diretório da aplicação
WORKDIR /usr/src/app

# Instalar dependências do sistema:
# - python3, make, g++: necessários para compilar módulos nativos do Node.js
# - firebird-dev: biblioteca de desenvolvimento do Firebird (cria symlink libfbclient.so)
# - ca-certificates: certificados SSL para conexões HTTPS
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    firebird-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf python3 /usr/bin/python

# Copiar arquivos de dependências
COPY package*.json ./

# Instalar dependências de produção
# Usa npm install pois não temos package-lock.json
RUN npm install --production --no-optional && \
    npm cache clean --force

# Copiar código da aplicação
COPY server.js ./

# Criar usuário não-root para segurança
RUN groupadd -g 1001 nodejs && \
    useradd -r -u 1001 -g nodejs nodejs

# Mudar ownership dos arquivos
RUN chown -R nodejs:nodejs /usr/src/app

# Usar usuário não-root
USER nodejs

# Expor porta da aplicação
EXPOSE 3030

# Health check para Docker/Swarm
# start-period aumentado para 60s devido aos testes de conexão
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3030/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Comando para iniciar a aplicação
CMD ["node", "server.js"]
