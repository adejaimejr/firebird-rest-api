// Gateway REST API para Firebird - n8n Integration
// Permite execução de queries SQL genéricas no Firebird via REST

require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const { createPool } = require('generic-pool');
const { createNativeClient, getDefaultLibraryFilename } = require('node-firebird-driver-native');

// ============================================================================
// CONFIGURAÇÕES
// ============================================================================

const app = express();
const PORT = process.env.PORT || 3030;

// Configuração do Firebird - SEM valores padrão (segurança)
const fbOptions = {
  host: process.env.FB_HOST,
  port: parseInt(process.env.FB_PORT || '3050'),
  database: process.env.FB_DATABASE,
  user: process.env.FB_USER,
  password: process.env.FB_PASSWORD
};

// Pool de conexões Firebird
const poolConfig = {
  max: parseInt(process.env.POOL_MAX || '10'),
  min: parseInt(process.env.POOL_MIN || '2'),
  idleTimeoutMillis: parseInt(process.env.POOL_IDLE_TIMEOUT || '30000'),
  acquireTimeoutMillis: 30000,
  evictionRunIntervalMillis: parseInt(process.env.POOL_CHECK_INTERVAL || '5000')
};

let pool = null;
let firebirdClient = null;

// Configurações de segurança
const API_KEY = process.env.API_KEY;
const ALLOW_WRITE_OPS = process.env.ALLOW_WRITE_OPS === 'true'; // Controla UPDATE/INSERT
const BLOCK_DDL = process.env.BLOCK_DDL !== 'false'; // Bloqueia DDL por padrão

// ============================================================================
// MIDDLEWARES
// ============================================================================

// Segurança HTTP headers
app.use(helmet());

// Parse JSON
app.use(express.json({ limit: '10mb' }));

// Logs de requisições
app.use(morgan('combined', {
  skip: (req) => req.path === '/health' // Não loga health checks
}));

// Rate limiting - proteção contra abuso
const limiter = rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW || '60000'), // 1 minuto
  max: parseInt(process.env.RATE_LIMIT_MAX || '100'), // 100 requisições por minuto
  message: {
    success: false,
    error: 'Muitas requisições. Tente novamente mais tarde.'
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/query', limiter);

// Middleware de autenticação via API Key
const authenticateApiKey = (req, res, next) => {
  const apiKey = req.headers['x-api-key'];

  if (!API_KEY) {
    console.error('⚠️  API_KEY não configurada no ambiente!');
    return res.status(500).json({
      success: false,
      error: 'Configuração de segurança ausente'
    });
  }

  if (!apiKey || apiKey !== API_KEY) {
    console.warn('❌ Tentativa de acesso não autorizado:', {
      ip: req.ip,
      path: req.path,
      hasKey: !!apiKey
    });
    return res.status(401).json({
      success: false,
      error: 'API Key inválida ou ausente'
    });
  }

  next();
};

// ============================================================================
// FUNÇÕES DE VALIDAÇÃO E SEGURANÇA
// ============================================================================

/**
 * Valida se a query SQL contém operações proibidas
 * @param {string} sql - Query SQL a ser validada
 * @returns {Object} { valid: boolean, error?: string }
 */
function validateSQL(sql) {
  if (!sql || typeof sql !== 'string') {
    return { valid: false, error: 'SQL inválido ou ausente' };
  }

  const sqlUpper = sql.trim().toUpperCase();

  // REGRA 1: Bloqueia DDL destrutivas (SEMPRE, se BLOCK_DDL = true)
  if (BLOCK_DDL) {
    const ddlPatterns = [
      /\bDROP\s+(TABLE|DATABASE|INDEX|VIEW|PROCEDURE|TRIGGER)\b/i,
      /\bTRUNCATE\s+TABLE\b/i,
      /\bALTER\s+(TABLE|DATABASE)\b/i,
      /\bCREATE\s+(TABLE|DATABASE|INDEX)\b/i,
    ];

    for (const pattern of ddlPatterns) {
      if (pattern.test(sql)) {
        return {
          valid: false,
          error: 'Operações DDL não são permitidas (DROP, TRUNCATE, ALTER, CREATE)'
        };
      }
    }
  }

  // REGRA 2: Bloqueia DML de escrita se ALLOW_WRITE_OPS = false
  if (!ALLOW_WRITE_OPS) {
    const dmlPatterns = [
      /^\s*UPDATE\b/i,
      /^\s*INSERT\b/i,
      /^\s*DELETE\b/i,
      /\bEXECUTE\s+PROCEDURE\b/i,
      /\bEXECUTE\s+BLOCK\b/i
    ];

    for (const pattern of dmlPatterns) {
      if (pattern.test(sql)) {
        return {
          valid: false,
          error: 'Operações de escrita não estão habilitadas (UPDATE, INSERT, DELETE)'
        };
      }
    }
  }

  return { valid: true };
}

/**
 * Registra query executada para auditoria
 * @param {string} sql - Query executada
 * @param {Array} params - Parâmetros da query
 * @param {Object} result - Resultado da execução
 * @param {string} ip - IP do cliente
 */
function auditLog(sql, params, result, ip) {
  const timestamp = new Date().toISOString();
  console.log('📊 AUDIT LOG:', {
    timestamp,
    ip,
    sql: sql.substring(0, 200) + (sql.length > 200 ? '...' : ''),
    params: params ? params.length : 0,
    success: result.success,
    rowCount: result.rowCount || 0,
    error: result.error || null
  });
}

// ============================================================================
// GERENCIAMENTO DO POOL DE CONEXÕES
// ============================================================================

/**
 * Cria e retorna string de conexão do Firebird
 */
function getConnectionString() {
  const host = fbOptions.host;
  const port = fbOptions.port;
  const database = fbOptions.database;

  // Formato: host:port/database ou host/database
  if (port && port !== 3050) {
    return `${host}/${port}:${database}`;
  }
  return `${host}:${database}`;
}

/**
 * Testa conexão única com Firebird antes de criar o pool
 */
async function testFirebirdConnection() {
  console.log('🧪 Testando conexão única com Firebird...');

  const connectionString = getConnectionString();
  console.log('📍 Connection String:', connectionString);
  console.log('📍 User:', fbOptions.user);

  let attachment = null;

  try {
    // Conecta ao banco
    attachment = await firebirdClient.connect(connectionString, {
      username: fbOptions.user,
      password: fbOptions.password
    });

    console.log('✅ Conexão teste OK!');

    // Testa query
    const transaction = await attachment.startTransaction();

    try {
      const resultSet = await attachment.executeQuery(transaction, 'SELECT 1 AS TEST FROM RDB$DATABASE');
      const rows = await resultSet.fetch();
      await resultSet.close();
      await transaction.commit();

      console.log('✅ Query teste OK! Resultado:', rows);
      console.log('✅ Desconectado com sucesso');

    } catch (queryErr) {
      await transaction.rollback();
      throw queryErr;
    }

  } finally {
    if (attachment) {
      await attachment.disconnect();
    }
  }
}

/**
 * Factory para criar conexões no pool
 */
const connectionFactory = {
  create: async () => {
    console.log('🔌 Criando nova conexão Firebird no pool...');
    const connectionString = getConnectionString();

    const attachment = await firebirdClient.connect(connectionString, {
      username: fbOptions.user,
      password: fbOptions.password
    });

    console.log('✅ Conexão criada no pool');
    return attachment;
  },

  destroy: async (attachment) => {
    console.log('🔌 Destruindo conexão do pool...');
    try {
      await attachment.disconnect();
      console.log('✅ Conexão destruída');
    } catch (err) {
      console.error('❌ Erro ao destruir conexão:', err);
    }
  },

  validate: async (attachment) => {
    try {
      // Testa se a conexão ainda está ativa
      const transaction = await attachment.startTransaction();
      await transaction.commit();
      return true;
    } catch (err) {
      console.error('⚠️  Conexão inválida no pool:', err.message);
      return false;
    }
  }
};

/**
 * Inicializa o pool de conexões Firebird
 */
async function initializePool() {
  console.log('🔌 Inicializando pool de conexões Firebird...');
  console.log('📍 Host:', fbOptions.host);
  console.log('📍 Port:', fbOptions.port);
  console.log('📍 Database:', fbOptions.database);
  console.log('📍 User:', fbOptions.user);
  console.log('🔄 Pool Config:', `min: ${poolConfig.min}, max: ${poolConfig.max}`);

  // Cria o pool usando generic-pool
  pool = createPool(connectionFactory, poolConfig);

  console.log('✅ Pool criado com sucesso!');

  // Testa o pool obtendo uma conexão
  console.log('🧪 Testando pool...');
  const testConnection = await pool.acquire();

  try {
    const transaction = await testConnection.startTransaction();
    const resultSet = await testConnection.executeQuery(transaction, 'SELECT 1 AS TEST FROM RDB$DATABASE');
    const rows = await resultSet.fetch();
    await resultSet.close();
    await transaction.commit();

    console.log('✅ Teste de pool OK! Resultado:', rows);
  } finally {
    await pool.release(testConnection);
  }
}

/**
 * Executa query no Firebird usando pool de conexões
 * @param {string} sql - Query SQL
 * @param {Array} params - Parâmetros da query
 * @returns {Promise<Array>}
 */
async function executeQuery(sql, params = []) {
  if (!pool) {
    throw new Error('Pool de conexões não inicializado');
  }

  let attachment = null;
  let transaction = null;

  try {
    // Obtém conexão do pool
    attachment = await pool.acquire();

    // Inicia transação
    transaction = await attachment.startTransaction();

    // Executa query
    if (params && params.length > 0) {
      // Query com parâmetros - usa prepared statement
      const statement = await attachment.prepare(transaction, sql);

      try {
        // Verifica se é SELECT ou DML
        const sqlUpper = sql.trim().toUpperCase();
        if (sqlUpper.startsWith('SELECT')) {
          const resultSet = await statement.executeQuery(transaction, params);
          // Usa fetchAsObject() para retornar objetos JSON com nomes de colunas
          const rows = await resultSet.fetchAsObject();
          await resultSet.close();
          await statement.dispose();
          await transaction.commit();
          return rows;
        } else {
          // UPDATE, INSERT, DELETE
          await statement.execute(transaction, params);
          await statement.dispose();
          await transaction.commit();
          return [];
        }
      } catch (err) {
        await statement.dispose();
        throw err;
      }
    } else {
      // Query sem parâmetros
      const sqlUpper = sql.trim().toUpperCase();
      if (sqlUpper.startsWith('SELECT')) {
        const resultSet = await attachment.executeQuery(transaction, sql);
        // Usa fetchAsObject() para retornar objetos JSON com nomes de colunas
        const rows = await resultSet.fetchAsObject();
        await resultSet.close();
        await transaction.commit();
        return rows;
      } else {
        // DML sem parâmetros
        await attachment.execute(transaction, sql);
        await transaction.commit();
        return [];
      }
    }

  } catch (error) {
    // Rollback em caso de erro
    if (transaction) {
      try {
        await transaction.rollback();
      } catch (rollbackErr) {
        console.error('❌ Erro ao fazer rollback:', rollbackErr);
      }
    }
    throw error;

  } finally {
    // Sempre retorna conexão ao pool
    if (attachment) {
      await pool.release(attachment);
    }
  }
}

// ============================================================================
// ENDPOINTS
// ============================================================================

/**
 * Health check endpoint
 * Usado pelo Traefik para verificar saúde do container
 */
app.get('/health', async (req, res) => {
  try {
    // Testa conexão com Firebird
    const result = await executeQuery('SELECT 1 AS HEALTH FROM RDB$DATABASE', []);

    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      firebird: 'connected',
      pool: pool ? 'active' : 'inactive',
      poolSize: pool ? pool.size : 0,
      poolAvailable: pool ? pool.available : 0,
      poolPending: pool ? pool.pending : 0
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      firebird: 'disconnected',
      error: error.message
    });
  }
});

/**
 * Endpoint principal para execução de queries
 * POST /query
 * Body: { sql: string, params?: array }
 * Headers: x-api-key
 */
app.post('/query', authenticateApiKey, async (req, res) => {
  const startTime = Date.now();
  const { sql, params = [] } = req.body;

  try {
    // Validação de segurança
    const validation = validateSQL(sql);
    if (!validation.valid) {
      auditLog(sql, params, { success: false, error: validation.error }, req.ip);
      return res.status(400).json({
        success: false,
        error: validation.error
      });
    }

    // Executa query
    console.log('🔍 Executando query:', sql.substring(0, 100) + '...');
    const result = await executeQuery(sql, params);

    const executionTime = Date.now() - startTime;

    // Resposta de sucesso
    const response = {
      success: true,
      rowCount: Array.isArray(result) ? result.length : 0,
      data: result,
      executionTime: `${executionTime}ms`
    };

    auditLog(sql, params, response, req.ip);
    res.json(response);

  } catch (error) {
    const executionTime = Date.now() - startTime;

    console.error('❌ Erro na execução:', error);

    const errorResponse = {
      success: false,
      error: error.message,
      executionTime: `${executionTime}ms`
    };

    auditLog(sql, params, errorResponse, req.ip);
    res.status(500).json(errorResponse);
  }
});

/**
 * Endpoint raiz - informações da API
 */
app.get('/', (req, res) => {
  res.json({
    service: 'Firebird API Gateway',
    version: '2.0.0',
    driver: 'node-firebird-driver-native',
    endpoints: {
      health: 'GET /health',
      query: 'POST /query (requer x-api-key)'
    },
    security: {
      ddlBlocked: BLOCK_DDL,
      writeOpsAllowed: ALLOW_WRITE_OPS
    },
    pool: pool ? {
      size: pool.size,
      available: pool.available,
      pending: pool.pending,
      min: poolConfig.min,
      max: poolConfig.max
    } : null
  });
});

/**
 * 404 handler
 */
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint não encontrado',
    path: req.path
  });
});

// ============================================================================
// INICIALIZAÇÃO E GRACEFUL SHUTDOWN
// ============================================================================

let server;

/**
 * Valida se todas as variáveis de ambiente obrigatórias estão definidas
 */
function validateEnvironment() {
  const requiredVars = {
    'API_KEY': API_KEY,
    'FB_HOST': fbOptions.host,
    'FB_DATABASE': fbOptions.database,
    'FB_USER': fbOptions.user,
    'FB_PASSWORD': fbOptions.password
  };

  const missing = [];

  for (const [varName, value] of Object.entries(requiredVars)) {
    if (!value || value === 'undefined' || value === '') {
      missing.push(varName);
    }
  }

  if (missing.length > 0) {
    console.error('');
    console.error('❌ ========================================');
    console.error('❌ ERRO: Variáveis de ambiente faltando!');
    console.error('❌ ========================================');
    console.error('');
    console.error('As seguintes variáveis são OBRIGATÓRIAS:');
    missing.forEach(varName => {
      console.error(`  ❌ ${varName}`);
    });
    console.error('');
    console.error('Configure estas variáveis no arquivo .env ou');
    console.error('nas environment variables do docker-compose.yml');
    console.error('');
    console.error('Dica: Copie .env.example para .env e preencha os valores');
    console.error('');
    throw new Error(`Variáveis obrigatórias faltando: ${missing.join(', ')}`);
  }

  console.log('✅ Validação de variáveis de ambiente: OK');
}

/**
 * Inicia o servidor
 */
async function startServer() {
  try {
    // Valida variáveis de ambiente obrigatórias
    validateEnvironment();

    // Inicializa cliente Firebird nativo
    console.log('🔧 Inicializando cliente Firebird nativo...');
    firebirdClient = createNativeClient(getDefaultLibraryFilename());
    console.log('✅ Cliente Firebird inicializado');

    // Testa conexão com Firebird ANTES de criar pool
    await testFirebirdConnection();

    // Inicializa pool de conexões
    await initializePool();

    // Inicia servidor HTTP
    server = app.listen(PORT, () => {
      console.log('');
      console.log('🚀 ========================================');
      console.log('🚀 Firebird API Gateway ONLINE v2.1');
      console.log('🚀 ========================================');
      console.log('📡 Porta:', PORT);
      console.log('🔐 Autenticação: API Key');
      console.log('🛡️  DDL Bloqueado:', BLOCK_DDL);
      console.log('✍️  Operações Escrita:', ALLOW_WRITE_OPS ? 'PERMITIDAS' : 'BLOQUEADAS');
      console.log('⚡ Rate Limit:', process.env.RATE_LIMIT_MAX || '100', 'req/min');
      console.log('🔌 Pool Conexões:', `${poolConfig.min}-${poolConfig.max}`);
      console.log('📚 Driver: node-firebird-driver-native');
      console.log('📊 Formato: JSON Objects (fetchAsObject)');
      console.log('🚀 ========================================');
      console.log('');
    });

  } catch (error) {
    console.error('💥 Erro fatal ao iniciar servidor:', error);
    process.exit(1);
  }
}

/**
 * Graceful shutdown - fecha conexões de forma segura
 */
async function gracefulShutdown(signal) {
  console.log('');
  console.log(`⚠️  Sinal ${signal} recebido. Iniciando shutdown gracioso...`);

  // Para de aceitar novas requisições
  if (server) {
    server.close(() => {
      console.log('✅ Servidor HTTP fechado');
    });
  }

  // Fecha pool de conexões
  if (pool) {
    try {
      await pool.drain();
      await pool.clear();
      console.log('✅ Pool de conexões fechado');
    } catch (err) {
      console.error('❌ Erro ao fechar pool:', err);
    }
  }

  // Fecha cliente Firebird
  if (firebirdClient) {
    try {
      await firebirdClient.dispose();
      console.log('✅ Cliente Firebird finalizado');
    } catch (err) {
      console.error('❌ Erro ao finalizar cliente:', err);
    }
  }

  console.log('👋 Shutdown completo. Até logo!');
  process.exit(0);
}

// Captura sinais de término
process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Captura erros não tratados
process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught Exception:', error);
  gracefulShutdown('EXCEPTION');
});

// Inicia o servidor
startServer();
