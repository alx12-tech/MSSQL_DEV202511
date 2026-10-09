/*
    Процедура: LOAD_CARRY
    Схема: Stage
    Назначение: загрузка данных из входящего буфера (слой STAGE) , 
        в таблицу FCT_CARRY слой Accounting
    Параметры:  
                mode - предустановки режимов
     процедура: загрузки данных
        - создать буфер с раcширением до идентификаторов
        - набрать данные из входящего буфера за период
        - сверить счета (по наим.) 
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые
        - сверить клиентов (по наим.)
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые
        - сверить договоры (по наим.)
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые

        - загрузка проводок: 
            - в идеале надо догружать только те которые новые или скорректированные
            - проблема: сверка параметров проводок (описаний, передаваемых классификаторов)
            - объем проводок не очень большой на этапе MVP
            - ввиду вышеизложенного, реализован прямой алгоритм:
                - сформировать набор проводок загруженных (TGT)
                - набрать набор проводок из существующего за период (SRC) - сформировать сторно
                - объединить наборы  и INSERT в таблицу проводок
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER procedure STAGE.LOAD_CARRY
     @MODE nvarchar(512) = 'current period'

WITH execute as OWNER
-------------------
AS
BEGIN
    SET NOCOUNT ON;

    --действительные параметры даты текущего периода
    declare
            @YEAR   int = cast(year(getdate()) as int)
        ,   @MONTH  int = cast(month(getdate()) as int)


    --для "предыдущего периода" (загрузка после отчётной даты)
    if @MODE = 'previous period'
        SELECT
            @year = year(DATEADD(MONTH, -1, getdate())),
            @month = month(DATEADD(MONTH, -1, getdate()))

    --Создание времянки
    CREATE TABLE #carry_buffer (
        --обработка дат
        LOAD_DATE       datetime2       default getdate(),
        CARRY_DATE      datetime2,
        turnover        NUMERIC(28,12)  default 0.0,
        --обработка счёта
        account_name    nvarchar(1024),
        id_account      int             default -1,
        bal2            nvarchar(512)   default '',
        --обработка договора
        agreement_name  nvarchar(1024),
        id_agreement    int             default -1,
        --обработка клиента
        client_name     nvarchar(1024),
        id_client       int             default -1,
        --обработка доп.параметров
        carry_ground    nvarchar(1024),
        extra_data      nvarchar(1024),
        --служебная отметка
        is_del          int             default 0
    )

    -- набор данных из входящего буфера, данные агрегируются
    insert into #carry_buffer (
        carry_date,
        turnover,
        account_name,
        agreement_name,
        client_name,
        carry_ground,
        bal2,
        extra_data
        )
    select
        cast(stg.carry_date as date),
        sum(turnover_sum),
        stg.account_name,
        stg.agreement_name,
        stg.client_name,
        stg.carry_ground,
        stg.bal2,
        stg.extra_data
    from STAGE.BUF_FCT_CARRY stg
    where
        year(stg.carry_date) = @YEAR and
        month(stg.carry_date) = @MONTH
    GROUP BY
        cast(stg.carry_date as date),
        stg.account_name,
        stg.agreement_name,
        stg.client_name,
        stg.carry_ground,
        stg.bal2,
        stg.extra_data

    --сверка клиентов
    MERGE INTO Accounting.dic_client as tgt
    using (
        select distinct ltrim(rtrim(client_name)) as client_name
        from #carry_buffer
        where client_name is not null and client_name <> ''
    ) as src
    ON src.client_name = tgt.client_name
    WHEN not matched BY TARGET
        THEN
            INSERT (client_name)
            VALUES (client_name)
    OUTPUT $action, deleted.*, inserted.*
    ;

    --подтягиваем клиентов - нужны для договоров
    UPDATE cb
    SET cb.id_client = dc.id_client
    FROM #carry_buffer cb
    INNER JOIN Accounting.Dic_client dc ON ltrim(rtrim(cb.client_name)) = dc.client_name

    --сверка договоров
    MERGE INTO Accounting.dic_agreement as tgt
    using (
        select distinct ltrim(rtrim(agreement_name)) as agreement_name, id_client
        from #carry_buffer
        where agreement_name is not null and agreement_name <> ''
    ) as src
    ON src.agreement_name = tgt.agreement_name and src.id_client = tgt.id_client
    WHEN not matched BY TARGET
        THEN
            INSERT (agreement_name, id_client)
            VALUES (agreement_name, id_client)
    OUTPUT $action, deleted.*, inserted.*
    ;
      --Определяем активную версию справочника BAL2 (берем первую активную/доступную)
    declare @current_bal2_version_id int;
    select top 1 @current_bal2_version_id = id_bal2_version
    from Accounting.DIC_BAL2_VERSION
    where is_del = 0
    order by id_bal2_version desc;

    -- Если версий нет вообще, жестко зашиваем 1
    set @current_bal2_version_id = isnull(@current_bal2_version_id, 1);


    --Сверка счетов
     MERGE INTO Accounting.dic_account as tgt
    using (
        select distinct
             ltrim(rtrim(cb.account_name)) as account_name
            ,ltrim(rtrim(cb.bal2)) as bal2_code
        from #carry_buffer cb
        where cb.account_name IS NOT NULL and cb.account_name <> ''
    ) as src
    ON src.account_name = tgt.account_name
    WHEN not matched BY TARGET
        THEN
            INSERT (
                account_name,
                id_client,
                id_bal2
            )
            VALUES (
                src.account_name,
                1,
                -- ЛОГИКА ПОИСКА: Если в будущем bal2 начнет приходить не пустым, раскомментировать нижнюю строку ISNULL:
                -- isnull((select top 1 b.id_bal2 from Accounting.DIC_BAL2 b where b.name = cast(src.bal2_code as varchar(5)) and b.id_bal2_version = @current_bal2_version_id and b.id_del = 0), 1)
                1 -- Текущая заглушка (ссылается на запись '*' с id_bal2 = 1)
            )
    OUTPUT $action, deleted.*, inserted.*
    ;

    --формируем целевую таблицу (типы данных полностью синхронны с Accounting.FCT_CARRY)
    create table #fct_carry_tgt (
        carry_date      DATEtime2       NOT NULL
       ,carry_ground    nvarchar(1024)  NOT NULL
       ,id_account      int             NOT NULL
       ,id_agreement    int             NOT NULL
       ,VL              numeric(28,12)  NOT NULL DEFAULT 0
       ,SRC_date        datetime        NOT NULL DEFAULT cast(getdate() as datetime)
    )

    --сторнирующая часть
    insert into #fct_carry_tgt (
         carry_date
        ,carry_ground
        ,id_account
        ,id_agreement
        ,VL
        ,SRC_date
    )
    select
         carry_date
        ,concat(N'сторно:', carry_ground) -- добавлен префикс N для юникода
        ,id_account
        ,id_agreement
        ,(-1) * VL
        ,SRC_date
    from Accounting.Fct_Carry fc
    where year(fc.carry_date) = @YEAR and
          month(fc.carry_date) = @MONTH

    --Обновляем идентификаторы в буфере перед переносом
    UPDATE cb
    SET
          cb.id_client    = isnull(dc.id_client, 1)      -- если клиент не найден, ставим дефолтного (1)
        , cb.id_agreement = isnull(dag.id_agreement, -1) -- временный маркер, если договор не найден
        , cb.id_account   = isnull(da.id_account, 1)     -- дефолт 1 для счета
    FROM #carry_buffer cb
    LEFT JOIN Accounting.dic_client dc
        ON dc.client_name = ltrim(rtrim(cb.client_name))
    LEFT JOIN Accounting.dic_agreement dag
        ON dag.agreement_name = ltrim(rtrim(cb.agreement_name)) AND dag.id_client = dc.id_client
    LEFT JOIN Accounting.dic_account da
        ON da.account_name = ltrim(rtrim(cb.account_name))
    WHERE cb.is_del = 0;

    --Определяем ID какого-нибудь существующего договора для дефолтного клиента (на случай, если у записи не нашелся договор)
    declare @default_agreement_id int;
    select top 1 @default_agreement_id = id_agreement
    from Accounting.dic_agreement a
    where a.id_client = 1;

    -- Если у дефолтного клиента еще нет ни одного договора, берем вообще любой первый попавшийся из справочника, чтобы не упал FK NOT NULL
    if @default_agreement_id is null
        select top 1 @default_agreement_id = id_agreement from Accounting.dic_agreement;

    --устанавливающая часть: собираем проводки из буфера в #fct_carry_tgt
    insert into #fct_carry_tgt (
         carry_date
        ,carry_ground
        ,id_account
        ,id_agreement
        ,VL
        ,SRC_date
    )
    select
         CARRY_DATE
        ,isnull(carry_ground, N'Не указано')
        ,id_account
        -- Если договор не определен, подставляем вычисленный безопасный ID договора
        ,case when id_agreement = -1 then isnull(@default_agreement_id, 1) else id_agreement end
        ,turnover
        ,LOAD_DATE
    from #carry_buffer
    where is_del = 0;

    --Финал: прямой перенос накопленных данных (сторно + новые) в физическую таблицу Accounting.FCT_CARRY
    insert into Accounting.FCT_CARRY (
         carry_date
        ,carry_ground
        ,id_account
        ,id_agreement
        ,VL
        ,SRC_date
    )
    select
         carry_date
        ,carry_ground -- Прямая вставка nvarchar -> nvarchar без CAST
        ,id_account
        ,id_agreement
        ,VL
        ,SRC_date
    from #fct_carry_tgt;

END
GO
