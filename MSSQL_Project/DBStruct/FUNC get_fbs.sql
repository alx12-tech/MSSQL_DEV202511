/*
    Табличная функция
    Назначение:
        формирование отчёта по балансу
    Входные параметры:
        отчёт по балансу
    Выходные параметры:
        номер периода
        номер типа расчётов
        номер корректировки (в общем случае не обязателен)
    Описание:
        возвращает таблицу с отчётом
        используется как самостоятельно так и в составе других процедур/функций, как источник данных для витрин(?)

        служит базой для функций-обёрток, схлопывающих служебные (id_corr и id_type)
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER function Accounting.get_fBS (
    @id_period int,
    @id_type int,
    @id_corr int = 0
    )
RETURNS @result table (
        id_period int,
        id_type int,
        id_corr int,
        id_account int,
        id_client int,
        id_agreement int,
        VL_SUM numeric(28,12)
        )
WITH execute as OWNER
AS
BEGIN
    -- Объявляем табличную переменную 
    DECLARE @typelist TABLE (id_type INT);

    -- Разворачиваем иерархию типов вниз от переданного @id_type (версия иерархии = 1)
    INSERT INTO @typelist (id_type)
    SELECT id_node 
    FROM Accounting.getTypeHierarchy(1, @id_type);

    -- Если иерархия ничего не вернула (например, тип не найден), добавляем сам переданный тип как базовый
    IF NOT EXISTS (SELECT 1 FROM @typelist)
    BEGIN
        INSERT INTO @typelist (id_type) VALUES (@id_type);
    END

    -- Собираем и агрегируем инкрементальные остатки из витрины DM_REST
    INSERT INTO @result (
        id_period,
        id_type,
        id_corr,
        id_account,
        id_client,
        id_agreement,
        VL_SUM
    )
    SELECT 
        adr.id_period,
        @id_type AS id_type, -- Возвращаем запрошенный корневой тип для удобства аналитики
        CASE WHEN @id_corr = 0 THEN 0 ELSE adr.id_corr END AS id_corr, -- Группируем id_corr, если запрошены все сразу
        adr.id_account,
        adr.id_client,
        adr.id_agreement,
        SUM(adr.[value]) AS VL_SUM -- Математическое сложение (+ остатки и - сторно) дает чистый баланс
    FROM Accounting.dm_rest adr
    WHERE adr.id_period = @id_period
      AND adr.id_type IN (SELECT id_type FROM @typelist)
      AND (@id_corr = 0 OR adr.id_corr = @id_corr) -- Логика необязательного параметра корректировки
    GROUP BY 
        adr.id_period,
        CASE WHEN @id_corr = 0 THEN 0 ELSE adr.id_corr END,
        adr.id_account,
        adr.id_client,
        adr.id_agreement
    HAVING SUM(adr.[value]) <> 0; -- Отсекаем полностью закрывшиеся в ноль балансы для чистоты отчета

    RETURN;
END
GO


/*
тестирование

SELECT * FROM Accounting.get_fBS(202601, 1, 0);
*/