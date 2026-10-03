/*
    Функция возвращает чистые обороты за указанный период (приходные и расходные движения). 
    Так как в самой таблице DM_REST обороты затираются/дополняются при перезапусках, 
    самый надежный и архитектурно правильный способ получить чистый оборот (P&L) — вытащить его напрямую из первоисточника, 
    то есть из таблицы проводок Accounting.FCT_CARRY.

*/

USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER function Accounting.get_PL (
    @id_period int
    )
RETURNS @result table (
        id_period int,
        id_client int,
        id_account int,
        id_agreement int,
        turnover_vl numeric(28,12)
        )
WITH execute as OWNER
AS
BEGIN
    DECLARE @left_margin DATE;
    DECLARE @right_margin DATE;

    -- Извлекаем границы периода по его ID
    SELECT 
        @left_margin = left_margin,
        @right_margin = right_margin
    FROM Accounting.dic_period
    WHERE id_period = @id_period;

    -- Если период не найден, возвращаем пустую таблицу
    IF @left_margin IS NOT NULL AND @right_margin IS NOT NULL
    BEGIN
        INSERT INTO @result (id_period, id_client, id_account, id_agreement, turnover_vl)
        SELECT 
             @id_period
            ,da.id_client
            ,fc.id_account
            ,fc.id_agreement
            ,SUM(fc.VL) AS turnover_vl
        FROM Accounting.FCT_CARRY fc
        INNER JOIN Accounting.DIC_ACCOUNT da ON fc.id_account = da.id_account
        WHERE fc.carry_date >= @left_margin AND fc.carry_date < @right_margin
        GROUP BY da.id_client, fc.id_account, fc.id_agreement;
    END

    RETURN;
END
GO
/*
select * from accounting.dic_period
select * from  Accounting.get_PL(202510)
*/