--Análise Integrada de Acidentes Rodoviários Federais (2023 a 2025)
--Autor: André Lucas da Costa Pereira
--Ferramenta: DuckDB
--Fonte de dados: Dados Abertos da PRF


------------------------------------------
--PARTE 1: INGESTÃO E INTEGRAÇÃO DE DADOS
------------------------------------------

-- Os arquivos CSV usam a codificação 'latin-1' para preservar caracteres acentuados.

-- Lê e exibe 10 registros dos acidentes de 2023 utilizando a função read_csv_auto
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2023.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)
limit 10;

-- Lê e exibe 10 registros dos acidentes de 2024 utilizando a função read_csv_auto
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2024.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)
limit 10;

-- Lê e exibe 10 registros dos acidentes de 2025 utilizando a função read_csv_auto
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2025.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)
limit 10;

--O código lê os três arquivos CSV de acidentes (2023, 2024, 2025), junta todos numa única tabela chamada acidentes_prf_historico
create or replace table acidentes_prf_historico as
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2023.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)
union all
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2024.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
)
union all
select * from read_csv_auto(
    'dados_2023_a_2025/datatran2025.csv',
    delim = ';',
    header = true,
    encoding = 'latin-1',
    sample_size = -1
);


---------------------------------------
--PARTE 2: LIMPEZA E SELEÇÃO DE COLUNAS
---------------------------------------

-- Foi criada uma view chamada vw_acidentes_limpa que contem apenas as colunas relevantes para a análise, excluindo as colunas latitude, longitude, regional, delegacia e uop.
create or replace view vw_acidentes_limpa as
select * exclude (latitude, longitude, regional, delegacia, uop)
from acidentes_prf_historico;


------------------------------------------------------------
--PARTE 3: ENGENHARIA DE RECURSOS (CRIAÇÃO DE NOVAS COLUNAS)
------------------------------------------------------------

-- Cria uma view com variáveis derivadas para a análise dos acidentes.
create or replace view vw_acidentes_enriquecida as
select *,

    --Acidente_fatal: Variável-alvo binária. Atribuido 1 se a coluna mortos for maior ou igual a 1; caso contrário, 0.
    case when mortos >= 1 then 1 else 0 end as acidente_fatal,

    -- Extrai o ano e o mês da data do acidente.
    year(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) as ano_acidente,
    month(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) as mes_acidente,

    -- Variável binária: 1 para acidentes ocorridos no sábado ou domingo.
    case
        when lower(trim(dia_semana)) in ('sábado', 'sabado', 'domingo') then 1
        else 0
    end as fim_de_semana,

    -- Classifica períodos de maior fluxo: fim de ano, Carnaval ou dias normais.
    case
        when (
            month(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) = 12
            and day(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) >= 20
        )
        or (
            month(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) = 1
            and day(try_strptime(cast(data_inversa as varchar), '%Y-%m-%d')) <= 2
        ) then 'Fim de Ano'
        when cast(data_inversa as date) between date '2023-02-18' and date '2023-02-21'
          or cast(data_inversa as date) between date '2024-02-10' and date '2024-02-13'
          or cast(data_inversa as date) between date '2025-03-01' and date '2025-03-04'
        then 'Carnaval'
        else 'Normal'
    end as data_comemorativa

from vw_acidentes_limpa;


-----------------------------------------------------
--PARTE 4: QUESTÕES DE NEGÓCIO (CONSULTAS ANALÍTICAS)
------------------------------------------------------

----------------------------------
-- Nível 1: Visão Geral e Temporal
----------------------------------

-- Questão 1: Tendência Anual e Severidade.
-- Para cada ano (2023, 2024, 2025), traz total de acidentes, total de vítimas fatais
-- (soma de mortos) e a taxa global de letalidade (% de acidentes fatais sobre o total).
select
    ano_acidente,
    count(*) as total_acidentes,
    sum(mortos) as total_vitimas_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by ano_acidente
order by ano_acidente;


-- Questão 2: Sazonalidade Mensal das Ocorrências.
-- Agrupa os acidentes por mes_acidente (2023 a 2025 combinados) e calcula a taxa de
-- letalidade de cada mês, para identificar o pico e verificar se coincide com férias.
select
    mes_acidente,
    count(*) as total_acidentes,
    sum(mortos) as total_vitimas_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by mes_acidente
order by taxa_letalidade_pct desc;


-- Questão 3: A Influência da Luminosidade (Fase do Dia).
-- Compara o volume absoluto de acidentes com a proporção de acidentes fatais em cada
-- fase_dia, para verificar se a noite é proporcionalmente mais letal que o dia.
select
    fase_dia,
    count(*) as total_acidentes,
    sum(acidente_fatal) as total_acidentes_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by fase_dia
order by taxa_letalidade_pct desc;


-- Questão 4: O Impacto dos Finais de Semana.
-- Usa a variável fim_de_semana para comparar a taxa de letalidade entre finais de
-- semana e dias úteis, e calcula o risco relativo (taxa do final de semana dividida
-- pela taxa do dia útil) para responder diretamente se o risco muda consideravelmente.
with taxas_periodo as (
    select
        case when fim_de_semana = 1 then 'Final de Semana' else 'Dia Útil' end as tipo_dia,
        count(*) as total_acidentes,
        sum(acidente_fatal) as total_acidentes_fatais,
        sum(acidente_fatal) * 1.0 / count(*) as taxa_letalidade
    from vw_acidentes_enriquecida
    group by fim_de_semana
)
select
    tipo_dia,
    total_acidentes,
    total_acidentes_fatais,
    round(100.0 * taxa_letalidade, 2) as taxa_letalidade_pct,
    round(
        taxa_letalidade / max(case when tipo_dia = 'Dia Útil' then taxa_letalidade end) over (),
        2
    ) as risco_relativo_vs_dia_util
from taxas_periodo
order by taxa_letalidade_pct desc;


-------------------------------------------------------
-- Nível 2: Análise de Risco (Lift e Fatores de Causa)
-------------------------------------------------------

-- Questão 5: O Perigo Oculto na Dinâmica da Colisão (Tipo de Acidente).
-- Calcula o Lift (taxa de letalidade do tipo / taxa de letalidade global) para
-- tipo_acidente, considerando apenas tipos com pelo menos 100 registros.
with taxa_global as (
    select 100.0 * sum(acidente_fatal) / count(*) as taxa_letalidade_global
    from vw_acidentes_enriquecida
)
select
    v.tipo_acidente,
    count(*) as total_acidentes,
    sum(v.acidente_fatal) as total_acidentes_fatais,
    round(100.0 * sum(v.acidente_fatal) / count(*), 2) as taxa_letalidade_pct,
    round((100.0 * sum(v.acidente_fatal) / count(*)) / tg.taxa_letalidade_global, 2) as lift
from vw_acidentes_enriquecida v
cross join taxa_global tg
group by v.tipo_acidente, tg.taxa_letalidade_global
having count(*) >= 100
order by lift desc;


-- Questão 6: Ranking de Causas Associadas à Letalidade.
-- Repete a lógica do Lift, agora agrupando por causa_acidente, para as 5 causas
-- presumíveis com maior Lift.
with taxa_global as (
    select 100.0 * sum(acidente_fatal) / count(*) as taxa_letalidade_global
    from vw_acidentes_enriquecida
)
select
    v.causa_acidente,
    count(*) as total_acidentes,
    sum(v.acidente_fatal) as total_acidentes_fatais,
    round(100.0 * sum(v.acidente_fatal) / count(*), 2) as taxa_letalidade_pct,
    round((100.0 * sum(v.acidente_fatal) / count(*)) / tg.taxa_letalidade_global, 2) as lift
from vw_acidentes_enriquecida v
cross join taxa_global tg
group by v.causa_acidente, tg.taxa_letalidade_global
order by lift desc
limit 5;


-- Questão 7: Análise da Infraestrutura (Traçado da Via).
-- Compara a taxa de letalidade entre trechos de "Reta" e "Curva", considerando
-- apenas traçados com mais de 500 acidentes registrados no total.
select
    tracado_via,
    count(*) as total_acidentes,
    sum(acidente_fatal) as total_acidentes_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by tracado_via
having count(*) > 500
order by taxa_letalidade_pct desc;


----------------------------------------------------------
-- Nível 3: Análise Multivariada (Cruzamento de Variáveis)
----------------------------------------------------------

-- Questão 8: Condições Agravantes (Pista vs. Clima).
-- Cruza tipo_pista e condicao_metereologica para achar a combinação com maior taxa
-- de letalidade, considerando apenas combinações com pelo menos 50 registros.
select
    tipo_pista,
    condicao_metereologica,
    count(*) as total_acidentes,
    sum(acidente_fatal) as total_acidentes_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by tipo_pista, condicao_metereologica
having count(*) >= 50
order by taxa_letalidade_pct desc;


-- Questão 9: Pontos Críticos Noturnos (BR x Fase do Dia).
-- Filtra acidentes ocorridos à noite e ranqueia as 10 rodovias (BRs) com maior
-- número absoluto de vítimas fatais nessa condição de luminosidade.
-- Uso de lower(trim(...)) para não depender se o valor está gravado com letras
-- maiúsculas ou minúsculas na base.
select
    br,
    sum(mortos) as total_vitimas_fatais
from vw_acidentes_enriquecida
where lower(trim(fase_dia)) = 'plena noite'
group by br
order by total_vitimas_fatais desc
limit 10;


-- Questão 10: O Efeito de Períodos Festivos.
-- Usa a coluna data_comemorativa (Parte 3) para comparar volume e gravidade dos
-- acidentes entre 'Fim de Ano', 'Carnaval' e dias 'Normais'.
select
    data_comemorativa,
    count(*) as total_acidentes,
    sum(mortos) as total_vitimas_fatais,
    round(100.0 * sum(acidente_fatal) / count(*), 2) as taxa_letalidade_pct
from vw_acidentes_enriquecida
group by data_comemorativa
order by taxa_letalidade_pct desc;


-------------------------------------------
-- Nível 4: Casos Críticos e Foco Geográfico
-------------------------------------------

-- View temporária para isolar os acidentes de altíssima gravidade (mortos >= 3),
-- reaproveitada nas duas partes da Questão 11.
create or replace view vw_acidentes_criticos as
select *
from vw_acidentes_enriquecida
where mortos >= 3;

-- Questão 11a: Acidentes de Altíssima Gravidade. Estado (uf) que lidera o ranking
-- absoluto de ocorrências com 3 ou mais mortos.
select
    uf,
    count(*) as total_acidentes_criticos
from vw_acidentes_criticos
group by uf
order by total_acidentes_criticos desc;

-- Questão 11b: dentro desse grupo restrito (mortos >= 3), qual a principal causa relatada.
select
    causa_acidente,
    count(*) as total_ocorrencias
from vw_acidentes_criticos
group by causa_acidente
order by total_ocorrencias desc;


-- Questão 12: Direcionamento Regional em Pernambuco (Alocação de Viaturas).
-- Ranking dos 5 municípios de PE com maior número absoluto de acidentes fatais,
-- somando os anos de 2024 e 2025.
select
    municipio,
    sum(acidente_fatal) as total_acidentes_fatais
from vw_acidentes_enriquecida
where uf = 'PE'
  and ano_acidente in (2024, 2025)
group by municipio
order by total_acidentes_fatais desc
limit 5;





