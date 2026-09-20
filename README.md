# Análise de Acidentes Rodoviários Federais (2023–2025)

Análise em SQL (DuckDB) dos dados abertos da Polícia Rodoviária Federal (PRF), cobrindo os anos de 2023, 2024 e 2025. O projeto vai da ingestão dos dados brutos até consultas analíticas voltadas a responder perguntas de negócio sobre severidade, sazonalidade, condições de risco e priorização geográfica de recursos.

## Sobre o projeto

O objetivo é identificar padrões associados a acidentes fatais nas rodovias federais brasileiras, usando apenas SQL puro no DuckDB, sem ferramentas externas de BI. O script é organizado em 4 etapas sequenciais e termina em 12 consultas analíticas agrupadas por nível de complexidade.

## Fonte dos dados

Dados Abertos da PRF (`datatran2023.csv`, `datatran2024.csv`, `datatran2025.csv`), em formato CSV, delimitados por `;` e codificados em `latin-1`.

## Tecnologia utilizada

- **DuckDB**: banco analítico usado para ingestão, transformação e consulta dos dados, direto sobre os arquivos CSV.

## Estrutura do script

### Parte 1: Ingestão e Integração de Dados
Leitura dos três arquivos CSV com `read_csv_auto` e unificação em uma única tabela histórica (`acidentes_prf_historico`) via `UNION ALL`.

### Parte 2: Limpeza e Seleção de Colunas
Criação da view `vw_acidentes_limpa`, removendo colunas geodésicas e administrativas não utilizadas na análise (`latitude`, `longitude`, `regional`, `delegacia`, `uop`).

### Parte 3: Engenharia de Recursos
Criação da view `vw_acidentes_enriquecida`, com variáveis derivadas construídas via `CASE WHEN` e funções de data:

- `acidente_fatal`: variável-alvo binária (1 quando há ao menos uma morte)
- `ano_acidente` e `mes_acidente`: extraídos de `data_inversa`
- `fim_de_semana`: variável binária (sábado ou domingo)
- `data_comemorativa`: classifica o acidente em `Fim de Ano`, `Carnaval` ou `Normal`

### Parte 4: Questões de Negócio
12 consultas analíticas divididas em 4 níveis:

**Nível 1 — Visão Geral e Temporal**
1. Tendência anual de acidentes, mortes e taxa de letalidade
2. Sazonalidade mensal da letalidade
3. Influência da fase do dia (luminosidade) na letalidade
4. Impacto dos finais de semana, com cálculo de risco relativo frente aos dias úteis

**Nível 2 — Análise de Risco (Lift)**
5. Lift de letalidade por tipo de acidente
6. Top 5 causas de acidente por Lift de letalidade
7. Letalidade por traçado da via (reta vs. curva)

**Nível 3 — Análise Multivariada**
8. Cruzamento entre tipo de pista e condição meteorológica
9. Ranking das 10 rodovias (BRs) com mais vítimas fatais à noite
10. Efeito de períodos festivos (Carnaval e Fim de Ano) na letalidade

**Nível 4 — Casos Críticos e Foco Geográfico**
11. Estados e causas predominantes em acidentes de altíssima gravidade (3+ mortos)
12. Ranking dos municípios de Pernambuco (PE) com mais acidentes fatais em 2024–2025

## Como executar

1. Baixe os arquivos `datatran2023.csv`, `datatran2024.csv` e `datatran2025.csv` dos Dados Abertos da PRF.
2. Coloque os três arquivos na mesma pasta do script `.sql` (ou ajuste os caminhos no início do arquivo).
3. Abra o DuckDB (CLI, extensão do VS Code, ou interface de sua preferência).
4. Execute o script `.sql` de cima para baixo, sem pular blocos.

O script é idempotente: todos os comandos usam `CREATE OR REPLACE`, então pode ser executado quantas vezes forem necessárias sem gerar erro.

## Principais achados

- A letalidade não acompanha o volume: fases do dia e condições climáticas com menos acidentes em número absoluto concentram, proporcionalmente, mais mortes.
- Nevoeiro/neblina aparece à frente da chuva como a condição climática mais letal, tanto em pista simples quanto em pista dupla, contrariando a expectativa de que chuva seria o maior fator de risco.

## Autor

André Lucas da Costa Pereira
