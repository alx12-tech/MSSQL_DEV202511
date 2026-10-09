/*
разработана на основании штатной процедуры загрузки
*/

USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER procedure STAGE.LOAD_CARRY_INITIAL
WITH execute as OWNER
-------------------
AS
BEGIN
    SET NOCOUNT ON;

    -- Создание времянки (структура полностью идентична регулярной процедуре)
    CREATE TABLE #carry_buffer (
        LOAD_DATE       datetime2       default getdate(),
        CARRY_DATE      datetime2,
        turnover        NUMERIC(28,12)  default 0.0,
        account_name    nvarchar(1024),
        id_account      int             default -1,
        bal2            nvarchar(512)   default '',
        agreement_name  nvarchar(1024),
        id_agreement    int             default -1,
        client_name     nvarchar(1024),
        id_client       int             default -1,
        carry_ground    nvarchar(1024), 
        extra_data      nvarchar(1024),
        is_del          int             default 0
    )

    -- Набор данных из ВСЕГО входящего буфера без фильтрации по @YEAR и @MONTH
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
        cast(stg.carry_date as date), -- отбрасываем метки времени, оставляя только чистую дату
        sum(turnover_sum),
        stg.account_name,
        stg.agreement_name,
        stg.client_name,
        stg.carry_ground,
        stg.bal2,
        stg.extra_data
    from STAGE.BUF_FCT_CARRY stg
    -- Исключили WHERE-блок фильтрации периодов, чтобы забрать всю историю
    GROUP BY
        cast(stg.carry_date as date),
        stg.account_name,
        stg.agreement_name,
        stg.client_name,
        stg.carry_ground,
        stg.bal2,
        stg.extra_data;
    -- 

    -- Сверка клиентов (синхронизируем весь справочник)
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

    -- Подтягиваем ID клиентов для последующей привязки договоров
    UPDATE cb
    SET cb.id_client = dc.id_client
    FROM #carry_buffer cb
    INNER JOIN Accounting.Dic_client dc ON ltrim(rtrim(cb.client_name)) = dc.client_name

    -- Сверка договоров
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

    -- Сверка счетов
    -- Определяем активную версию справочника BAL2
    declare @current_bal2_version_id int;
    select top 1 @current_bal2_version_id = id_bal2_version
    from Accounting.DIC_BAL2_VERSION
    where is_del = 0
    order by id_bal2_version desc;

    set @current_bal2_version_id = isnull(@current_bal2_version_id, 1);

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
                -- Заглушка, подставляющая id_bal2 = 1 (План счетов верхний уровень)
                1
            )
    OUTPUT $action, deleted.*, inserted.*
    ;

    -- Формируем целевую таблицу для вставки (точно повторяет Accounting.FCT_CARRY)
    create table #fct_carry_tgt (
        carry_date      DATEtime2       NOT NULL
       ,carry_ground    nvarchar(1024)  NOT NULL 
       ,id_account      int             NOT NULL
       ,id_agreement    int             NOT NULL
       ,VL              numeric(28,12)  NOT NULL DEFAULT 0
       ,SRC_date        datetime        NOT NULL DEFAULT cast(getdate() as datetime)
    )

    -- Обновляем идентификаторы ключей в буфере по всей истории
    UPDATE cb
    SET
          cb.id_client    = isnull(dc.id_client, 1)      
        , cb.id_agreement = isnull(dag.id_agreement, -1) 
        , cb.id_account   = isnull(da.id_account, 1)     
    FROM #carry_buffer cb
    LEFT JOIN Accounting.dic_client dc 
        ON dc.client_name = ltrim(rtrim(cb.client_name))
    LEFT JOIN Accounting.dic_agreement dag 
        ON dag.agreement_name = ltrim(rtrim(cb.agreement_name)) AND dag.id_client = dc.id_client
    LEFT JOIN Accounting.dic_account da 
        ON da.account_name = ltrim(rtrim(cb.account_name))
    WHERE cb.is_del = 0;

    -- Поиск дефолтного договора для подстраховки FK ограничений
    declare @default_agreement_id int;
    select top 1 @default_agreement_id = id_agreement 
    from Accounting.dic_agreement 
    where id_client = 1;

    if @default_agreement_id is null
        select top 1 @default_agreement_id = id_agreement from Accounting.dic_agreement;

    -- Устанавливающая часть: переносим все проводки без ограничений по датам
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
        ,isnull(carry_ground, N'Первичная загрузка') -- Если основание пустое, маркируем как первичную загрузку
        ,id_account
        ,case when id_agreement = -1 then isnull(@default_agreement_id, 1) else id_agreement end 
        ,turnover
        ,LOAD_DATE
    from #carry_buffer
    where is_del = 0;

    -- Финальный шаг: вставка накопленного исторического массива в целевую таблицу FCT_CARRY
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
        ,carry_ground
        ,id_account
        ,id_agreement
        ,VL
        ,SRC_date
    from #fct_carry_tgt;

END
GO

