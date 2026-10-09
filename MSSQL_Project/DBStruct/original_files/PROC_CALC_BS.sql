/*
    Перенос Баланса в таблицу остатков на основе данных проводок (загруженных за текущий период)

    Для реализации инкрементального сторнирования логика: 
        вместо физического удаления строк через DELETE, 
        найти все записи предыдущего (последнего актуального) расчета для этого периода, 
        скопировать их с обратным знаком (-1 * [value]) и 
        записать в рамках нового расчета (@id_calc). 
        После этого в этот же расчет добавляем новые вычисленные остатки.
    
    Таким образом, если за один период расчет запускался трижды, в таблице DM_REST будут последовательно лежать:
        1. Запуск 1: Первые остатки (+)
        2. Запуск 2: Сторно первого запуска (-) и Новые остатки (+)
        3. Запуск 3: Сторно второго запуска (-) и Актуальные остатки (+)


*/
USE PersonalFinance_v4
GO

CREATE or ALTER procedure Accounting.CALC_BS
    @id_period int,
    @id_scenario int = 1 
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id_type INT = 1; 
    DECLARE @id_corr INT = 1; 
    DECLARE @proc_name NVARCHAR(1024) = OBJECT_NAME(@@PROCID);

    DECLARE @id_calc INT;
    DECLARE @left_margin DATE;
    DECLARE @right_margin DATE;

    -- 1. Получаем границы текущего периода
    SELECT 
        @left_margin = left_margin,
        @right_margin = right_margin
    FROM Accounting.dic_period
    WHERE id_period = @id_period;

    IF @left_margin IS NULL OR @right_margin IS NULL
    BEGIN
        RAISERROR('Указанный расчетный период id_period = %d не найден в Accounting.dic_period', 16, 1, @id_period);
        RETURN;
    END

    -- Регистрируем НОВЫЙ номер расчета
    EXEC Accounting.GET_NEW_CALC
        @id_calc = @id_calc OUTPUT,
        @proc_name = @proc_name,
        @id_scenario = @id_scenario,
        @id_corr = @id_corr;

    IF @id_calc IS NULL OR @id_calc = -1
    BEGIN
        RAISERROR('Не удалось инициализировать запись расчета в Accounting.GET_NEW_CALC', 16, 1);
        RETURN;
    END

    -- Заворачиваем весь расчет в безопасный блок TRY...CATCH
    BEGIN TRY
        BEGIN TRANSACTION;

        -- =========================================================================
        -- ИНКРЕМЕНТАЛЬНОЕ СТОРНИРОВАНИЕ
        -- =========================================================================
        DECLARE @last_active_calc_id INT;
        
        SELECT TOP 1 @last_active_calc_id = id_calc
        FROM Accounting.DM_REST
        WHERE id_period = @id_period 
          AND id_type = @id_type
          AND id_calc <> @id_calc
        ORDER BY id_calc DESC; 

        IF @last_active_calc_id IS NOT NULL
        BEGIN
            INSERT INTO Accounting.DM_REST (
                 id_period
                ,id_calc
                ,id_corr
                ,id_type
                ,id_client
                ,id_account
                ,id_agreement
                ,[value]
            )
            SELECT 
                 id_period
                ,@id_calc 
                ,@id_corr
                ,id_type
                ,id_client
                ,id_account
                ,id_agreement
                ,(-1.000000000000) * [value] 
            FROM Accounting.DM_REST
            WHERE id_period = @id_period 
              AND id_type = @id_type
              AND id_calc = @last_active_calc_id;
        END

        -- =========================================================================
        -- ВЫЧИСЛЕНИЕ НОВЫХ ОСТАТКОВ
        -- =========================================================================
        CREATE TABLE #current_turnover (
            id_client INT,
            id_account INT,
            id_agreement INT,
            turnover_vl NUMERIC(28,12)
        );

        INSERT INTO #current_turnover (id_client, id_account, id_agreement, turnover_vl)
        SELECT 
            da.id_client,
            fc.id_account,
            fc.id_agreement,
            SUM(fc.VL) AS turnover_vl
        FROM Accounting.FCT_CARRY fc
        INNER JOIN Accounting.DIC_ACCOUNT da ON fc.id_account = da.id_account
        WHERE fc.carry_date >= @left_margin AND fc.carry_date < @right_margin
        GROUP BY da.id_client, fc.id_account, fc.id_agreement;

        CREATE TABLE #previous_rest (
            id_client INT,
            id_account INT,
            id_agreement INT,
            rest_vl NUMERIC(28,12)
        );

        DECLARE @prev_id_period INT;
        SELECT TOP 1 @prev_id_period = id_period 
        FROM Accounting.dic_period 
        WHERE right_margin = @left_margin;

        IF @prev_id_period IS NOT NULL
        BEGIN
            INSERT INTO #previous_rest (id_client, id_account, id_agreement, rest_vl)
            SELECT 
                id_client,
                id_account,
                id_agreement,
                SUM([value]) AS rest_vl
            FROM Accounting.DM_REST
            WHERE id_period = @prev_id_period 
              AND id_type = @id_type
            GROUP BY id_client, id_account, id_agreement;
        END

        CREATE TABLE #final_calc (
            id_client INT,
            id_account INT,
            id_agreement INT,
            outgoing_vl NUMERIC(28,12)
        );

        INSERT INTO #final_calc (id_client, id_account, id_agreement, outgoing_vl)
        SELECT 
            ISNULL(p.id_client, t.id_client) AS id_client,
            ISNULL(p.id_account, t.id_account) AS id_account,
            ISNULL(p.id_agreement, t.id_agreement) AS id_agreement,
            ISNULL(p.rest_vl, 0.0) + ISNULL(t.turnover_vl, 0.0) AS outgoing_vl
        FROM #previous_rest p
        FULL OUTER JOIN #current_turnover t 
            ON p.id_account = t.id_account AND p.id_agreement = t.id_agreement;

        INSERT INTO Accounting.DM_REST (
             id_period
            ,id_calc
            ,id_corr
            ,id_type
            ,id_client
            ,id_account
            ,id_agreement
            ,[value]
        )
        SELECT 
             @id_period
            ,@id_calc
            ,@id_corr
            ,@id_type
            ,id_client
            ,id_account
            ,id_agreement
            ,outgoing_vl
        FROM #final_calc
        WHERE outgoing_vl <> 0; 

        COMMIT TRANSACTION;

        -- Закрываем расчет только при успехе транзакции
        EXEC Accounting.FINISH_NEW_CALC @id_calc = @id_calc OUTPUT;

        DROP TABLE #current_turnover;
        DROP TABLE #previous_rest;
        DROP TABLE #final_calc;

    END TRY
    BEGIN CATCH
        -- Если транзакция осталась открыта из-за ошибки — принудительно её откатываем
        IF @@TRANCOUNT > 0 
            ROLLBACK TRANSACTION;

        -- Маркируем расчет как ошибочный (ставим -1), чтобы не подвешивать date_end = NULL
        UPDATE Accounting.dic_calc 
        SET descr = CONCAT('ERROR: ', LEFT(ERROR_MESSAGE(), 900)), date_end = GETDATE() 
        WHERE id_calc = @id_calc;

        -- Перевыбрасываем ошибку для логирования во внешнем скрипте
        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE(), @ErrSev INT = ERROR_SEVERITY(), @ErrState INT = ERROR_STATE();
        RAISERROR(@ErrMsg, @ErrSev, @ErrState);
    END CATCH
END
GO
