USE PersonalFinance_v4
GO

DECLARE @TargetPeriodID INT = 202501; -- Задаем отчетный период (Январь 2025)
DECLARE @id_type INT = 1;             -- Бухгалтерские данные

-- Определяем ID предыдущего периода на основе хронологии
DECLARE @PrevPeriodID INT;
SELECT TOP 1 @PrevPeriodID = id_period 
FROM Accounting.dic_period 
WHERE right_margin = (SELECT left_margin FROM Accounting.dic_period WHERE id_period = @TargetPeriodID);

-- Строим ОСВ с текстовыми наименованиями аналитик
WITH InBalance AS (
    -- Входящий остаток (сумма на конец предыдущего периода)
    SELECT id_account, id_agreement, id_client, SUM([value]) AS incoming_bal
    FROM Accounting.DM_REST
    WHERE id_period = @PrevPeriodID AND id_type = @id_type
    GROUP BY id_account, id_agreement, id_client
),
Turnovers AS (
    -- Обороты за текущий период (из нашей новой функции get_PL)
    SELECT id_account, id_agreement, id_client, turnover_vl
    FROM Accounting.get_PL(@TargetPeriodID)
),
OutBalance AS (
    -- Исходящий остаток на конец текущего периода
    SELECT id_account, id_agreement, id_client, SUM([value]) AS outgoing_bal
    FROM Accounting.DM_REST
    WHERE id_period = @TargetPeriodID AND id_type = @id_type
    GROUP BY id_account, id_agreement, id_client
),
AllKeys AS (
    -- Собираем все уникальные комбинации аналитик, чтобы не потерять счета без движений
    SELECT id_account, id_agreement, id_client FROM InBalance
    UNION
    SELECT id_account, id_agreement, id_client FROM Turnovers
    UNION
    SELECT id_account, id_agreement, id_client FROM OutBalance
)
SELECT 
     @TargetPeriodID AS [Период]
    ,dc.client_name AS [Клиент]
    ,da.account_name AS [Счет]
    ,dag.agreement_name AS [Договор]
    -- Входящий остаток
    ,ISNULL(ib.incoming_bal, 0.0) AS [Входящее сальдо]
    -- Обороты периода разделяем по знаку для дебета/кредита (приход/расход)
    ,CASE WHEN t.turnover_vl > 0 THEN t.turnover_vl ELSE 0.0 END AS [Оборот Дт (Приход)]
    ,CASE WHEN t.turnover_vl < 0 THEN ABS(t.turnover_vl) ELSE 0.0 END AS [Оборот Кт (Расход)]
    -- Исходящий остаток
    ,ISNULL(ob.outgoing_bal, 0.0) AS [Исходящее сальдо]
FROM AllKeys k
LEFT JOIN InBalance ib ON k.id_account = ib.id_account AND k.id_agreement = ib.id_agreement AND k.id_client = ib.id_client
LEFT JOIN Turnovers t ON k.id_account = t.id_account AND k.id_agreement = t.id_agreement AND k.id_client = t.id_client
LEFT JOIN OutBalance ob ON k.id_account = ob.id_account AND k.id_agreement = ob.id_agreement AND k.id_client = ob.id_client
-- Подтягиваем справочники для визуализации отчета
INNER JOIN Accounting.DIC_ACCOUNT da ON k.id_account = da.id_account
INNER JOIN Accounting.DIC_CLIENT dc ON k.id_client = dc.id_client
INNER JOIN Accounting.DIC_AGREEMENT dag ON k.id_agreement = dag.id_agreement
ORDER BY [Клиент], [Счет];
GO
