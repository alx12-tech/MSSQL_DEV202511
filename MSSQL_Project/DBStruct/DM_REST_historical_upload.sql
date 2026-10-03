--перекладка тестовых или исторических даннных в таблицу остатков
USE PersonalFinance_v4
GO

SET NOCOUNT ON;

DECLARE @HistoryStartDate DATE = DATEADD(MONTH, -24, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1));
DECLARE @EndDate DATE = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1); 

DECLARE @LoopDate DATE = @HistoryStartDate;
DECLARE @CurrentLeftMargin DATE;
DECLARE @CurrentRightMargin DATE;
DECLARE @PeriodDescr VARCHAR(512);
DECLARE @GeneratedPeriodID INT;

PRINT '--- СТАРТ ИСТОРИЧЕСКОЙ ПЕРЕКЛАДКИ ДАННЫХ В DM_REST ---';

WHILE @LoopDate <= @EndDate
BEGIN
    SET @CurrentLeftMargin = @LoopDate;
    SET @CurrentRightMargin = DATEADD(MONTH, 1, @LoopDate);
    SET @PeriodDescr = CONCAT('Исторический период: ', DATENAME(MONTH, @LoopDate), ' ', YEAR(@LoopDate));
    SET @GeneratedPeriodID = YEAR(@LoopDate) * 100 + MONTH(@LoopDate);

    PRINT '-------------------------------------------------------';
    PRINT CONCAT('Обработка периода: ', @PeriodDescr, ' [ID: ', @GeneratedPeriodID, ']');

    -- Создание расчетного периода
    BEGIN TRY
        EXEC Accounting.CREATE_NEW_PERIOD
            @ID_PERIOD = @GeneratedPeriodID OUTPUT,
            @DESCR = @PeriodDescr,
            @Left_margin = @CurrentLeftMargin,
            @right_margin = @CurrentRightMargin;
    END TRY
    BEGIN CATCH
        PRINT CONCAT('Предупреждение/ошибка при создании периода (возможно, уже создан): ', ERROR_MESSAGE());
    END CATCH

    -- Восстанавливаем ID, если он сбросился в процедуре периода
    IF @GeneratedPeriodID = -1 or @GeneratedPeriodID IS NULL
        SET @GeneratedPeriodID = YEAR(@LoopDate) * 100 + MONTH(@LoopDate);

    -- Вызов расчета балансов
    BEGIN TRY
        EXEC Accounting.CALC_BS 
            @id_period = @GeneratedPeriodID,
            @id_scenario = 1;

        PRINT CONCAT('УСПЕШНО: Выполнен расчет баланса для периода: ', @GeneratedPeriodID);
    END TRY
    BEGIN CATCH
        -- Ловим внутреннее исключение из CALC_BS, пишем в лог и идем дальше
        PRINT CONCAT('КРИТИЧЕСКАЯ ОШИБКА периода ', @GeneratedPeriodID, ': ', ERROR_MESSAGE());
    END CATCH

    -- Переход к следующему месяцу
    SET @LoopDate = DATEADD(MONTH, 1, @LoopDate);
END

PRINT '-------------------------------------------------------';
PRINT '--- ПЕРЕКЛАДКА ИСТОРИЧЕСКИХ ДАННЫХ ЗАВЕРШЕНА ---';
GO
