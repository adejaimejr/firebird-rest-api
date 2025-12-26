# Guia de Queries Firebird para a API Gateway

> Guia completo para escrever queries SQL compatíveis com Firebird Dialect 1 (ERP Millennium e similares)

## 📋 Índice

- [Diferenças Dialect 1 vs Dialect 3](#diferenças-dialect-1-vs-dialect-3)
- [Sintaxe Básica](#sintaxe-básica)
- [Datas e Timestamps](#datas-e-timestamps)
- [Tipos de Dados](#tipos-de-dados)
- [Funções Comuns](#funções-comuns)
- [JOINs e Subqueries](#joins-e-subqueries)
- [Boas Práticas](#boas-práticas)
- [Exemplos Práticos](#exemplos-práticos)
- [Troubleshooting](#troubleshooting)

---

## Diferenças Dialect 1 vs Dialect 3

Seu banco Firebird está em **Dialect 1** (banco antigo/legado). Isso significa que algumas funcionalidades modernas do SQL não funcionam.

### ❌ O que NÃO funciona no Dialect 1

| Sintaxe Moderna (Dialect 3) | Erro |
|------------------------------|------|
| `CURRENT_DATE` | ❌ Database SQL dialect 1 does not support reference to DATE datatype |
| `CURRENT_TIMESTAMP` | ❌ Database SQL dialect 1 does not support reference to DATE datatype |
| `DATE '2025-12-26'` | ❌ Database SQL dialect 1 does not support reference to DATE datatype |
| `TIMESTAMP '2025-12-26 10:30:00'` | ❌ Database SQL dialect 1 does not support reference to DATE datatype |
| `BOOLEAN` (tipo nativo) | ❌ Não existe - usar `VARCHAR(1)` com 'T'/'F' |

### ✅ O que funciona no Dialect 1

| Use Isto | Descrição |
|----------|-----------|
| `'2025-12-26'` | String de data (formato: 'YYYY-MM-DD') |
| `CAST('TODAY' AS DATE)` | Data de hoje |
| `CAST('NOW' AS TIMESTAMP)` | Data e hora atual |
| `'T'` ou `'F'` | Valores booleanos (em campo VARCHAR) |

---

## Sintaxe Básica

### SELECT Simples

```sql
-- ✅ Correto
SELECT FIRST 10 * FROM PRODUTOS

-- ✅ Com WHERE
SELECT * FROM CLIENTES WHERE CODIGO = 123

-- ✅ Com ORDER BY
SELECT * FROM PRODUTOS ORDER BY DESCRICAO1

-- ✅ Limitando registros
SELECT FIRST 100 * FROM PEDIDOS ORDER BY DATA_EMISSAO DESC
```

### Uso de Parâmetros (Prepared Statements)

**No n8n - Body Parameters:**

```json
{
  "sql": "SELECT * FROM CLIENTES WHERE CODIGO = ? AND ATIVO = ?",
  "params": [123, "S"]
}
```

**Tipos de parâmetros:**
- Números: `123`, `45.99`
- Strings: `"texto"`, `"S"`, `"F"`
- Null: `null`

---

## Datas e Timestamps

### ❌ NÃO FUNCIONA (Dialect 3)

```sql
-- ❌ ERRADO - Vai dar erro!
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO = CURRENT_DATE

-- ❌ ERRADO - Vai dar erro!
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO = DATE '2025-12-26'

-- ❌ ERRADO - Vai dar erro!
LEFT JOIN VALORES VL ON VL.DATA = CURRENT_DATE
```

### ✅ FUNCIONA (Dialect 1)

```sql
-- ✅ CORRETO - Data específica como string
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO = '2025-12-26'

-- ✅ CORRETO - Data de hoje
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO = CAST('TODAY' AS DATE)

-- ✅ CORRETO - BETWEEN com strings de data
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO BETWEEN '2025-12-01' AND '2025-12-31'

-- ✅ CORRETO - Timestamp atual
SELECT * FROM AUDITORIA
WHERE DATA_HORA = CAST('NOW' AS TIMESTAMP)

-- ✅ CORRETO - Comparar com data fixa
LEFT JOIN VALORES_MOEDAS VL
  ON VL.MOEDA = L.MOEDA
  AND VL.DATA = CAST('TODAY' AS DATE)
```

### Exemplos Práticos com Datas

```sql
-- Pedidos de hoje
SELECT * FROM PEDIDOS
WHERE CAST(DATA_EMISSAO AS DATE) = CAST('TODAY' AS DATE)

-- Pedidos do mês atual
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO BETWEEN '2025-12-01' AND '2025-12-31'

-- Pedidos dos últimos 7 dias (use data fixa ou parâmetro)
SELECT * FROM PEDIDOS
WHERE DATA_EMISSAO >= '2025-12-19'

-- Extrair ano, mês, dia
SELECT
  EXTRACT(YEAR FROM DATA_EMISSAO) AS ANO,
  EXTRACT(MONTH FROM DATA_EMISSAO) AS MES,
  EXTRACT(DAY FROM DATA_EMISSAO) AS DIA
FROM PEDIDOS
```

---

## Tipos de Dados

### Campos Booleanos (VARCHAR)

No Millennium e ERPs similares, campos booleanos são armazenados como `VARCHAR(1)` com valores `'T'` (True) ou `'F'` (False).

```sql
-- ✅ CORRETO
SELECT * FROM LANCAMENTOS WHERE TITULO = 'F'
SELECT * FROM PRODUTOS WHERE ATIVO = 'T'
SELECT * FROM CLIENTES WHERE BLOQUEADO = 'F'

-- ❌ ERRADO - Não use TRUE/FALSE
SELECT * FROM LANCAMENTOS WHERE TITULO = FALSE  -- ❌ Erro!
```

### Campos Numéricos

```sql
-- ✅ Inteiros
SELECT * FROM PRODUTOS WHERE CODIGO = 123

-- ✅ Decimais
SELECT * FROM PRODUTOS WHERE PRECO > 99.90

-- ✅ Com casting
SELECT CAST(VALOR AS INTEGER) FROM PEDIDOS
```

### Campos de Texto

```sql
-- ✅ Comparação exata
SELECT * FROM CLIENTES WHERE NOME = 'JOAO SILVA'

-- ✅ LIKE (busca parcial)
SELECT * FROM PRODUTOS WHERE DESCRICAO1 LIKE '%VESTIDO%'

-- ✅ CONTAINING (busca case-insensitive)
SELECT * FROM PRODUTOS WHERE DESCRICAO1 CONTAINING 'vestido'

-- ✅ STARTING WITH (começa com)
SELECT * FROM CLIENTES WHERE NOME STARTING WITH 'MARIA'
```

---

## Funções Comuns

### Concatenação de Strings

```sql
-- ✅ Operador ||
SELECT COD_FILIAL || '-' || NOME AS FILIAL_COMPLETA
FROM FILIAIS

-- ✅ Com COALESCE para NULL
SELECT COD_FILIAL || '-' || COALESCE(FANTASIA, NOME) AS FILIAL
FROM FILIAIS
```

### Funções de Agregação

```sql
-- ✅ COUNT, SUM, AVG, MIN, MAX
SELECT
  COUNT(*) AS TOTAL_PEDIDOS,
  SUM(VALOR_TOTAL) AS SOMA_VALORES,
  AVG(VALOR_TOTAL) AS MEDIA_VALORES,
  MIN(DATA_EMISSAO) AS PRIMEIRA_VENDA,
  MAX(DATA_EMISSAO) AS ULTIMA_VENDA
FROM PEDIDOS
WHERE DATA_EMISSAO BETWEEN '2025-12-01' AND '2025-12-31'
```

### Funções de String

```sql
-- ✅ SUBSTRING
SELECT SUBSTRING(DESCRICAO1 FROM 1 FOR 50) AS DESC_CURTA
FROM PRODUTOS

-- ✅ UPPER/LOWER
SELECT UPPER(NOME) AS NOME_MAIUSCULO FROM CLIENTES
SELECT LOWER(EMAIL) AS EMAIL_MINUSCULO FROM CLIENTES

-- ✅ TRIM
SELECT TRIM(NOME) AS NOME_SEM_ESPACOS FROM CLIENTES

-- ✅ CAST
CAST(SUBSTRING((COD_BANCO || ' - ' || NOME) FROM 1 FOR 140) AS VARCHAR(140))
```

### Condicionais

```sql
-- ✅ CASE WHEN
SELECT
  CODIGO,
  NOME,
  CASE
    WHEN ATIVO = 'T' THEN 'Ativo'
    WHEN ATIVO = 'F' THEN 'Inativo'
    ELSE 'Desconhecido'
  END AS STATUS_DESC
FROM CLIENTES

-- ✅ COALESCE (primeiro valor não-nulo)
SELECT COALESCE(FANTASIA, NOME, 'Sem Nome') AS NOME_EXIBIR
FROM FILIAIS

-- ✅ NULLIF
SELECT NULLIF(DESCONTO, 0) AS DESCONTO_VALIDO
FROM PRODUTOS
```

---

## JOINs e Subqueries

### INNER JOIN

```sql
SELECT
  P.NUMERO,
  C.NOME AS CLIENTE,
  P.VALOR_TOTAL
FROM PEDIDOS P
INNER JOIN CLIENTES C ON C.CODIGO = P.COD_CLIENTE
WHERE P.DATA_EMISSAO >= '2025-12-01'
```

### LEFT JOIN

```sql
SELECT
  P.COD_PRODUTO,
  P.DESCRICAO1,
  E.QUANTIDADE
FROM PRODUTOS P
LEFT JOIN ESTOQUE E ON E.PRODUTO = P.PRODUTO
WHERE P.ATIVO = 'T'
```

### Múltiplos JOINs

```sql
SELECT
  L.LANCAMENTO,
  C.DESCRICAO AS CONTA,
  F.NOME AS FILIAL,
  B.NOME AS BANCO
FROM LANCAMENTOS L
LEFT JOIN CONTAS C ON C.CONTA = L.CONTA
LEFT JOIN FILIAIS F ON F.FILIAL = L.FILIAL
LEFT JOIN BANCOS B ON B.BANCO = L.BANCO
WHERE L.DATA_VENCIMENTO >= '2025-12-01'
```

### Subquery no SELECT

```sql
SELECT
  P.NUMERO,
  P.VALOR_TOTAL,
  (SELECT COUNT(*)
   FROM ITENS_PEDIDO I
   WHERE I.PEDIDO = P.NUMERO) AS QTD_ITENS
FROM PEDIDOS P
WHERE P.DATA_EMISSAO >= '2025-12-01'
```

### Subquery no WHERE

```sql
SELECT * FROM PRODUTOS
WHERE CODIGO IN (
  SELECT DISTINCT COD_PRODUTO
  FROM ITENS_PEDIDO
  WHERE DATA_EMISSAO >= '2025-12-01'
)
```

---

## Boas Práticas

### 1. Use FIRST para Limitar Resultados

```sql
-- ✅ Sempre limite grandes consultas
SELECT FIRST 100 * FROM PRODUTOS
SELECT FIRST 1000 * FROM PEDIDOS WHERE DATA_EMISSAO >= '2025-01-01'
```

### 2. Evite SELECT *

```sql
-- ❌ Evite - retorna muitos campos desnecessários
SELECT * FROM PRODUTOS

-- ✅ Prefira - selecione apenas o necessário
SELECT COD_PRODUTO, DESCRICAO1, REFERENCIA, PRECO
FROM PRODUTOS
```

### 3. Use Índices (WHERE, JOIN, ORDER BY)

```sql
-- ✅ Campos indexados: chaves primárias, códigos, datas
SELECT * FROM PEDIDOS WHERE NUMERO = 123  -- Rápido (PK)
SELECT * FROM CLIENTES WHERE CODIGO = 456  -- Rápido (PK)

-- ⚠️ Pode ser lento se NOME não tiver índice
SELECT * FROM CLIENTES WHERE NOME LIKE '%SILVA%'
```

### 4. Teste Incrementalmente

```sql
-- Passo 1: Teste a tabela principal
SELECT FIRST 5 * FROM LANCAMENTOS

-- Passo 2: Adicione WHERE
SELECT FIRST 5 * FROM LANCAMENTOS
WHERE TITULO = 'F'

-- Passo 3: Adicione JOINs um por vez
SELECT FIRST 5 L.*, C.DESCRICAO
FROM LANCAMENTOS L
LEFT JOIN CONTAS C ON C.CONTA = L.CONTA
WHERE L.TITULO = 'F'

-- Passo 4: Adicione mais campos conforme necessário
```

### 5. Formatação Clara

```sql
-- ✅ Legível e fácil de debugar
SELECT
  L.LANCAMENTO,
  L.DATA_EMISSAO,
  L.VALOR_INICIAL,
  C.DESCRICAO AS CONTA,
  F.NOME AS FILIAL
FROM LANCAMENTOS L
LEFT JOIN CONTAS C ON C.CONTA = L.CONTA
LEFT JOIN FILIAIS F ON F.FILIAL = L.FILIAL
WHERE L.TITULO = 'F'
  AND L.DATA_VENCIMENTO BETWEEN '2025-12-01' AND '2025-12-31'
ORDER BY L.DATA_VENCIMENTO
```

---

## Exemplos Práticos

### Exemplo 1: Listar Produtos Ativos

```sql
SELECT
  COD_PRODUTO,
  DESCRICAO1,
  REFERENCIA,
  CAST(SUBSTRING(DESCRICAO1 FROM 1 FOR 50) AS VARCHAR(50)) AS DESC_CURTA
FROM PRODUTOS
WHERE ATIVO = 'T'
ORDER BY DESCRICAO1
```

**No n8n:**
```json
{
  "sql": "SELECT COD_PRODUTO, DESCRICAO1, REFERENCIA FROM PRODUTOS WHERE ATIVO = 'T' ORDER BY DESCRICAO1",
  "params": []
}
```

### Exemplo 2: Pedidos por Período

```sql
SELECT FIRST 100
  P.NUMERO,
  P.DATA_EMISSAO,
  P.VALOR_TOTAL,
  C.NOME AS CLIENTE
FROM PEDIDOS P
LEFT JOIN CLIENTES C ON C.CODIGO = P.COD_CLIENTE
WHERE P.DATA_EMISSAO BETWEEN '2025-12-01' AND '2025-12-31'
ORDER BY P.DATA_EMISSAO DESC
```

**No n8n com parâmetros:**
```json
{
  "sql": "SELECT FIRST 100 P.NUMERO, P.DATA_EMISSAO, P.VALOR_TOTAL, C.NOME AS CLIENTE FROM PEDIDOS P LEFT JOIN CLIENTES C ON C.CODIGO = P.COD_CLIENTE WHERE P.DATA_EMISSAO BETWEEN ? AND ? ORDER BY P.DATA_EMISSAO DESC",
  "params": ["2025-12-01", "2025-12-31"]
}
```

### Exemplo 3: Estoque de Produtos

```sql
SELECT
  P.COD_PRODUTO,
  P.DESCRICAO1,
  COALESCE(SUM(E.QUANTIDADE), 0) AS ESTOQUE_TOTAL
FROM PRODUTOS P
LEFT JOIN ESTOQUE E ON E.PRODUTO = P.PRODUTO
WHERE P.ATIVO = 'T'
GROUP BY P.COD_PRODUTO, P.DESCRICAO1
HAVING COALESCE(SUM(E.QUANTIDADE), 0) > 0
ORDER BY ESTOQUE_TOTAL DESC
```

### Exemplo 4: Lançamentos Financeiros (Query Complexa)

```sql
SELECT
  L.LANCAMENTO,
  L.DATA_VENCIMENTO,
  L.VALOR_INICIAL,
  L.VALOR_PAGO,
  C.DESCRICAO AS DESC_CONTA,
  F.COD_FILIAL || '-' || COALESCE(F.FANTASIA, F.NOME) AS NOME_FILIAL,
  B.NOME AS BANCO,
  PC.CLASSIFICACAO || '-' || PC.DESCRICAO AS PLANO_CONTAS
FROM LANCAMENTOS L
LEFT JOIN CONTAS C ON C.CONTA = L.CONTA
LEFT JOIN FILIAIS F ON F.FILIAL = L.FILIAL
LEFT JOIN BANCOS B ON B.BANCO = L.BANCO
LEFT JOIN PLANO_CONTAS PC ON PC.PCONTA = L.PCONTA
WHERE L.TITULO = 'F'
  AND L.DATA_VENCIMENTO BETWEEN '2025-12-23' AND '2025-12-25'
ORDER BY L.DATA_VENCIMENTO
```

### Exemplo 5: Relatório de Vendas com Totalizadores

```sql
SELECT
  F.COD_FILIAL,
  F.NOME AS FILIAL,
  COUNT(P.NUMERO) AS QTD_PEDIDOS,
  SUM(P.VALOR_TOTAL) AS TOTAL_VENDAS,
  AVG(P.VALOR_TOTAL) AS TICKET_MEDIO
FROM PEDIDOS P
LEFT JOIN FILIAIS F ON F.FILIAL = P.FILIAL
WHERE P.DATA_EMISSAO BETWEEN '2025-12-01' AND '2025-12-31'
  AND P.STATUS = 'F'
GROUP BY F.COD_FILIAL, F.NOME
ORDER BY TOTAL_VENDAS DESC
```

---

## Troubleshooting

### Erro: "Database SQL dialect 1 does not support reference to DATE datatype"

**Causa:** Você usou `CURRENT_DATE`, `CURRENT_TIMESTAMP`, `DATE '...'` ou `TIMESTAMP '...'`

**Solução:**
```sql
-- ❌ ERRADO
WHERE DATA = CURRENT_DATE
WHERE DATA = DATE '2025-12-26'

-- ✅ CORRETO
WHERE DATA = CAST('TODAY' AS DATE)
WHERE DATA = '2025-12-26'
```

### Erro: "Dynamic SQL Error - SQL error code = -104"

**Causa:** Sintaxe SQL incompatível com Dialect 1

**Soluções:**
1. Verifique se não está usando `CURRENT_DATE` ou `DATE '...'`
2. Verifique se campos booleanos usam `'T'`/`'F'` em vez de `TRUE`/`FALSE`
3. Teste a query em partes menores

### Erro: "Token unknown" ou "Invalid token"

**Causa:** Caractere especial ou sintaxe incorreta

**Soluções:**
1. Verifique aspas: use `'` para strings, não `"`
2. Escape caracteres especiais em nomes: `"nome-com-hifen"`
3. Verifique vírgulas e parênteses

### Query retorna dados incorretos

**Soluções:**
1. Verifique JOINs: `INNER JOIN` vs `LEFT JOIN`
2. Teste sem JOINs primeiro
3. Adicione `WHERE` para limitar e verificar
4. Use `FIRST 10` para testes rápidos

### Query muito lenta

**Soluções:**
1. Adicione `FIRST N` para limitar resultados
2. Reduza campos no SELECT (evite `SELECT *`)
3. Verifique se está usando campos indexados no WHERE
4. Simplifique JOINs desnecessários
5. Adicione índices no banco (se tiver permissão)

---

## Como Testar Queries no n8n

### 1. Configure o HTTP Request Node

- **Method:** POST
- **URL:** `https://sua-api.com/query`
- **Authentication:** Header Auth
  - Name: `x-api-key`
  - Value: `sua-chave-api`
- **Body Content Type:** JSON
- **Specify Body:** Using Fields Below

### 2. Adicione Body Parameters

- **Campo 1:**
  - Name: `sql`
  - Value: Sua query SQL

- **Campo 2:**
  - Name: `params`
  - Value: `[]` (ou array de parâmetros)

### 3. Teste Incremental

```sql
-- Teste 1: Estrutura básica
SELECT FIRST 5 * FROM SUA_TABELA

-- Teste 2: Com WHERE
SELECT FIRST 5 * FROM SUA_TABELA WHERE CAMPO = 'VALOR'

-- Teste 3: Com 1 JOIN
SELECT FIRST 5 A.*, B.NOME
FROM SUA_TABELA A
LEFT JOIN OUTRA_TABELA B ON B.ID = A.ID

-- Teste 4: Query completa
-- (só adicione mais JOINs e campos após testar cada passo)
```

### 4. Debugging

Se der erro, verifique o campo `error` na resposta:

```json
{
  "success": false,
  "error": "Dynamic SQL Error\n-SQL error code = -104\n-Database SQL dialect 1 does not support reference to DATE datatype",
  "executionTime": "3ms"
}
```

Procure neste guia pelo erro e aplique a correção!

---

## Dicas Específicas para ERP Millennium

### Campos Comuns

```sql
-- Produtos
PRODUTO (PK, integer)
COD_PRODUTO (código único, varchar)
DESCRICAO1 (descrição principal)
DESCRICAO2 (descrição secundária)
REFERENCIA (referência/código de barras)
ATIVO ('T'/'F')

-- Clientes
CODIGO (PK, integer)
NOME (razão social)
FANTASIA (nome fantasia)
CPF_CGC (CPF/CNPJ)

-- Pedidos
NUMERO (PK, integer)
DATA_EMISSAO (data/timestamp)
VALOR_TOTAL (decimal)
STATUS ('A'=Aberto, 'F'=Fechado, etc)

-- Lançamentos Financeiros
LANCAMENTO (PK, integer)
TITULO ('T'/'F' - se é título ou não)
DATA_VENCIMENTO (data)
DATA_EMISSAO (data)
VALOR_INICIAL (decimal)
VALOR_PAGO (decimal)
EFETUADO ('T'/'F')
```

### Queries Úteis

```sql
-- Saldo em estoque por produto
SELECT
  P.COD_PRODUTO,
  P.DESCRICAO1,
  COALESCE(SUM(E.QUANTIDADE), 0) AS SALDO
FROM PRODUTOS P
LEFT JOIN ESTOQUE E ON E.PRODUTO = P.PRODUTO
GROUP BY P.COD_PRODUTO, P.DESCRICAO1

-- Contas a receber em aberto
SELECT
  L.LANCAMENTO,
  L.DATA_VENCIMENTO,
  L.VALOR_INICIAL - L.VALOR_PAGO AS SALDO
FROM LANCAMENTOS L
WHERE L.TIPO = 'R'
  AND L.EFETUADO = 'F'
  AND L.VALOR_PAGO < L.VALOR_INICIAL
ORDER BY L.DATA_VENCIMENTO

-- Top 10 produtos mais vendidos
SELECT FIRST 10
  P.COD_PRODUTO,
  P.DESCRICAO1,
  SUM(I.QUANTIDADE) AS QTD_VENDIDA
FROM ITENS_PEDIDO I
INNER JOIN PRODUTOS P ON P.PRODUTO = I.PRODUTO
WHERE I.DATA_EMISSAO >= '2025-01-01'
GROUP BY P.COD_PRODUTO, P.DESCRICAO1
ORDER BY QTD_VENDIDA DESC
```

---

## Recursos Adicionais

### Documentação Firebird

- [Firebird SQL Reference](https://firebirdsql.org/file/documentation/html/en/referenceguide/fblangref40/firebird-40-language-reference.html)
- [Firebird Dialect Guide](https://firebirdsql.org/file/documentation/html/en/referenceguide/fblangref25/firebird-25-language-reference.html#fblangref25-structure-dialects)

### Ferramentas de Teste

- **FlameRobin** - Cliente gráfico Firebird (gratuito)
- **IBExpert** - IDE avançado para Firebird
- **DBeaver** - Cliente universal de bancos de dados

### Suporte

- 📖 [README.md](README.md) - Documentação completa da API
- 🚀 [QUICK_START.md](QUICK_START.md) - Guia rápido de deploy
- 🐛 [GitHub Issues](https://github.com/adejaimejr/firebird-rest-api/issues) - Reporte problemas

---

**Desenvolvido para integração n8n + Firebird ERP Millennium** 🚀
