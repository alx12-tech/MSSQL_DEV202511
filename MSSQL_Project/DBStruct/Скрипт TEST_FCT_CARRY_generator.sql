/*
скрипт-генератор для наполнения таблицы STAGE.BUF_FCT_CARRY . 

временные таблицы со списками клиентов, счетов и договоров с учетом логики знака (приход/расход) для сумм транзакций.
Скрипт генерирует случайные комбинации объектов, распределяя даты внутри заданного исторического горизонта.
*/
USE PersonalFinance_v4
GO

-- Очищаем таблицу перед генерацией
TRUNCATE TABLE STAGE.BUF_FCT_CARRY;
GO

SET NOCOUNT ON;

--  Создаем справочники вариантов (наборы тестовых сущностей)
CREATE TABLE #src_clients (client_name NVARCHAR(1024), is_income INT);    -- 1 = Доходный клиент, 0 = Расходный клиент
CREATE TABLE #src_accounts (account_name NVARCHAR(1024), bal2 NVARCHAR(512));
CREATE TABLE #src_agreements (agreement_name NVARCHAR(1024), is_income INT); -- 1 = Приход, 0 = Расход

--  Наполняем варианты клиентов с флагами (без смешанного типа)
INSERT INTO #src_clients (client_name, is_income) VALUES 
(N'ПАО Газпром (Заказчик)', 1),     -- Только доход
(N'ООО Рога и Копыта (Покупатель)', 1), -- Только доход
(N'ИП Иванов И.И. (Фриланс)', 1),   -- Только доход
(N'Магазин Пятерочка (Поставщик)', 0), -- Только расход
(N'ООО МосЭнергоСбыт', 0),            -- Только расход
(N'ООО РЖД', 0),            -- Только расход
(N'ООО Телеком-телеком', 0),            -- Только расход
(N'ООО Продуктовый магазин', 0),            -- Только расход
(N'ООО ХозБытТОвары', 0),            -- Только расход
(N'ООО Туоператор', 0),            -- Только расход
(N'Бизнес-Центр Плаза (Аренда)', 0);  -- Только расход




-- Наполняем варианты счетов
INSERT INTO #src_accounts (account_name, bal2) VALUES 
(N'Основной расчетный счет', N'40702'),
(N'Валютный счет (USD)', N'40702'),
(N'Карта Корпоративная', N'40817'),
(N'Накопительный счет', N'40702');

-- Наполняем варианты договоров с флагом прихода/расхода
INSERT INTO #src_agreements (agreement_name, is_income) VALUES 
(N'Договор поставки №12', 1),        -- Приход
(N'Заработная плата', 1),            -- Приход
(N'Оказание консультационных услуг', 1), -- Приход
(N'Оплата аренды офиса', 0),         -- Расход
(N'Покупка канцелярии', 0),          -- Расход
(N'Оплата за интернет и связь', 0),  -- Расход
(N'Покупка продуктов', 0),  -- Расход
(N'Билеты на автобус', 0),  -- Расход
(N'Покупка турпутевки', 0),  -- Расход
(N'Билеты кинотеатр', 0),  -- Расход
(N'Кафе и рестораны', 0),  -- Расход
(N'Прочие хозяйственные расходы', 0); -- Расход


-- Задаем параметры генератора
DECLARE @TotalRows INT = 5000;              -- Общее количество генерируемых строк
DECLARE @StartDate DATETIME2 = '2025-01-01'; -- Начало горизонта генерации дат
DECLARE @EndDate DATETIME2 = '2026-12-31';   -- Конец горизонта генерации дат

-- Нумерация для выбора по случайному индексу
ALTER TABLE #src_clients ADD id INT IDENTITY(1,1);
ALTER TABLE #src_accounts ADD id INT IDENTITY(1,1);
-- Для договоров отдельно нумерация внутри типов ниже, чтобы выборка была точной

DECLARE @MaxClient INT = (SELECT MAX(id) FROM #src_clients);
DECLARE @MaxAccount INT = (SELECT MAX(id) FROM #src_accounts);
DECLARE @DaysDiff INT = DATEDIFF(DAY, @StartDate, @EndDate);

-- Основной цикл генерации данных
DECLARE @Counter INT = 1;

WHILE @Counter <= @TotalRows
BEGIN
    -- Вычисляем случайные индексы для клиента и счета
    DECLARE @RandomClientIdx INT = CAST(RAND() * @MaxClient AS INT) + 1;
    DECLARE @RandomAccountIdx INT = CAST(RAND() * @MaxAccount AS INT) + 1;
    
    -- Вычисляем случайную дату в заданном диапазоне
    DECLARE @RandomDays INT = CAST(RAND() * @DaysDiff AS INT);
    DECLARE @RandomHours INT = CAST(RAND() * 24 AS INT);
    DECLARE @RandomMinutes INT = CAST(RAND() * 60 AS INT);
    DECLARE @GeneratedDate DATETIME2 = DATEADD(MINUTE, @RandomMinutes, DATEADD(HOUR, @RandomHours, DATEADD(DAY, @RandomDays, @StartDate)));

    -- Переменные для хранения выбранных сущностей
    DECLARE @ClientName NVARCHAR(1024), @ClientIncomeFlag INT;
    DECLARE @AccountName NVARCHAR(1024), @Bal2 NVARCHAR(512);
    DECLARE @AgreementName NVARCHAR(1024);
    DECLARE @TurnoverSum NUMERIC(28,12);

    -- Выбираем клиента и его тип (доход/расход)
    SELECT @ClientName = client_name, @ClientIncomeFlag = is_income FROM #src_clients WHERE id = @RandomClientIdx;
    
    -- Выбираем счет
    SELECT @AccountName = account_name, @Bal2 = bal2 FROM #src_accounts WHERE id = @RandomAccountIdx;

    -- На основании типа клиента выбираем только подходящий по типу договор
    -- Чтобы не пересоздавать индексы в цикле, выбираем случайную строку через CTE
    ;WITH FilteredAgreements AS (
        SELECT agreement_name, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as row_num
        FROM #src_agreements
        WHERE is_income = @ClientIncomeFlag
    )
    SELECT @AgreementName = agreement_name 
    FROM FilteredAgreements 
    WHERE row_num = CAST(RAND() * (SELECT COUNT(*) FROM FilteredAgreements) AS INT) + 1;

    -- Генерация суммы транзакции в зависимости от флага
    DECLARE @BaseAmount NUMERIC(28,12) = CAST((RAND() * 49900 + 100) AS NUMERIC(28,12));
    
    IF @ClientIncomeFlag = 1
        SET @TurnoverSum = @BaseAmount;                  -- Клиент доходный -> сумма всегда положительная
    ELSE
        SET @TurnoverSum = -1.000000000000 * @BaseAmount;         -- Клиент расходный -> сумма всегда отрицательная

    -- Вставка строки в буфер STAGE.BUF_FCT_CARRY
    INSERT INTO STAGE.BUF_FCT_CARRY (
         carry_date
        ,turnover_sum
        ,account_name
        ,agreement_name
        ,client_name
        ,carry_ground
        ,bal2
        ,extra_data
    )
    VALUES (
         @GeneratedDate
        ,@TurnoverSum
        ,@AccountName
        ,@AgreementName
        ,@ClientName
        ,CONCAT(N'Тестовая проводка. Контрагент: ', @ClientName, N', основание: ', @AgreementName)
        ,@Bal2
        ,CONCAT(N'Доп.инфо: ', NEWID())
    );

    SET @Counter = @Counter + 1;
END;

-- Очистка временных таблиц-справочников
DROP TABLE #src_clients;
DROP TABLE #src_accounts;
DROP TABLE #src_agreements;

-- Проверка сгенерированного результата
SELECT 
    COUNT(*) AS [Всего строк],
    SUM(CASE WHEN turnover_sum > 0 THEN 1 ELSE 0 END) AS [Кол-во Приходов (>0)],
    SUM(CASE WHEN turnover_sum < 0 THEN 1 ELSE 0 END) AS [Кол-во Расходов (<0)],
    MIN(carry_date) AS [Минимальная дата],
    MAX(carry_date) AS [Максимальная дата]
FROM STAGE.BUF_FCT_CARRY;

-- Кросс-таблица для проверки: какой клиент с какими суммами сгенерировался
SELECT 
    client_name AS [Клиент],
    COUNT(*) AS [Количество операций],
    MIN(turnover_sum) AS [Минимальная сумма],
    MAX(turnover_sum) AS [Максимальная сумма]
FROM STAGE.BUF_FCT_CARRY
GROUP BY client_name;
GO

