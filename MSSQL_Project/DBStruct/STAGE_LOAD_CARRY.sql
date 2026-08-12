/*
    Процедура: LOAD_CARRY
    Схема: Stage
    Параметры: номер счёта,
        параметры даты задаются для перспективного применения "закрытых" периодов
        mode - предустановки режимов
    Параметры по умолчанию: нулевой номер, процедура выполнит алгоритм для всеч встретившихся счетов

     процедура: загрузки данных
        - создать буфер с раcширением до идентификаторов
        - набрать данные из входящего буфера - только за отчётный период
        - сверить счета (по наим.) - счета только для дебетовых операций?? клиеинтские счета не сверяем пока
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые
            -- дополнить идентификаторы
        - сверить клиентов (по наим.)
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые
            -- дополнить идентификаторы
        - сверить договоры (по наим.)
            -- подтянуть идентификаторы
            -- где не подтянулись - создать новые
            -- дополнить идентификаторы
            -- создание клиентов (ключ - наименование)
        - сформировать набор проводок (TGT)
        - набрать набор проводок из существующего за период (SRC), пометить все как DEL
        - сверить два набора (описание ниже по тексту)
        - откинуть все которые DEL
        - оставшиеся INSERT в таблицу проводок
*/

drop rpocedute IF EXISTS LOAD_CARRY

CREATE procedure LOAD_CARRY
    @ID_ACCOUNT int,
    @MODE nvarchar(512) = 'current period',
    @YEAR int = year(getdate()),--
    @MONTH int = month(getdate())--

WITH execute as OWNER

BEGIN

--для "предыдущего периода" определяем даты
    if @MODE = 'previous period'
    then
        SELECT
            --сдвигаем месяц
            @MONTH = DATEPART(MONTH, DATEADD(MONTH, -1, GETDATE())),
            --год тоже сдвигаем для января
            case DATEPART(MONTH, GETDATE)))
                when 1 then @YEAR = DATEPART(YEAR, DATEADD(MONTH, -1, GETDATE()))
                else @YEAR = DATEPART(YEAR, GETDATE())

    --Создание времянки
    CREATE TABLE #carry_buffer (
        LOAD_DATE       date default getdate(),
        CARRY_DATE      date,
        turnover        double default 0,--если вдруг в поле дичь
        account_name    nvarchar(1024),
        id_account      int default -1,--используется как признак неопределённого значения
        bal2            nvarchar(512) default '',--в общем случае разметка может и не приехать, тогда она будет дополнена позже... возможно, но это нежелательный сценарий
        agreement_name  nvarchar(1024),
        id_agreement    int default -1,--используется как признак неопределённого значения
        client_name     nvarchar(1024),
        id_client       int default -1,--используется как признак неопределённого значения
        carry_ground    nvarchar(1024),
        extra_data      nvarchar(1024),
        is_del tiny_int int default 0--1 к удалению, 0 без удаления

    )

-- набор данных из входящего буфера
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
        cast(carry_date as date),--отбрасываем метки времени
        turnover_sum,
        account_name,
        agreement_name,
        client_name,
        carry_ground,
        bal2,
        extra_data
    from STAGE.CARRY_BUF stg
    where   --совпадение только по году-месяцу, даты не важны
        year(stg.carry_date) = @YEAR and
        month(stg.carry_date) = @MONTH
    GROUP BY
        carry_date,
        turnover,
        account_name,
        agreement_name,
        client_name,
        carry_ground,
        bal2,
        extra_data

--TRY_CONVERT(DATE, '28.12.2026', 104);
--CONVERT(VARCHAR(10), GETDATE(), 23); -> 2026-06-28

    MERGE INTO dic_client as tgt
    using (
        select distinct client_name
        from #carry_buffer
        where client_name not is null and client_name <> ''
    ) as src
    ON src.client_name = tgt.client_name
    --WHEN matched THEN PASS
    WHEN not matched BY TARGET
        THEN
            INSERT (
                tgt.client_name,
            )
            VALUES (
                src.client_name
            )
    OUTPUT $action, deleted.*, inserted.*
    --INTO LOG.DIC_CLIENT_LOG
    ;--MERGE


    MERGE INTO dic_agreement as tgt
    using (
        select distinct agreement_name
        from #carry_buffer
        where agreement_name not is null and agreement_name <> ''
    ) as src
    ON src.agreement_name = tgt.agreement_name
    --WHEN matched THEN PASS
    WHEN not matched BY TARGET
        THEN
            INSERT (
                tgt.agreement_name,
            )
            VALUES (
                src.agreement_name
            )
    OUTPUT $action, deleted.*, inserted.*
    --INTO LOG.DIC_CLIENT_LOG
    ;--MERGE


    --сверка счетов
    --дополнить новыми клиентами
    --при оптимизации: апдейт клиентов буфера разместить здесь вместо JOIN

    MERGE INTO dic_account as tgt
    using (
        select distinct cd.account_name, dc.id_client
        from #carry_buffer cb
        left join dic_client dc on dc.client_name = cb.client_name--новые клиенты
        where account_name not is null and account_name <> ''
    ) as src
    ON src.account_name = tgt.account_name
    --WHEN matched THEN PASS
    WHEN not matched BY TARGET
        THEN
            INSERT (
                tgt.account_name,
                tgt.id_client
                tgt.bal2
            )
            VALUES (
                src.account_name,
                src.id_client,
                src.bal2
            )
    OUTPUT $action, deleted.*, inserted.*
    --INTO LOG.DIC_CLIENT_LOG
    ;--MERGE

/*
    Проверяем проводки:
        TGT - набранный входящий буфер, должен содержать всё за период
            формат даты - усекается до даты (время при ручном заводе может плавать - на этапе отладки будет мешать
            поле extra_data - может содержать дополнительные даннные... может использоваться для разделения
                            например нескольких однаковых платежей (заказ кофе в кофейне) - накладывает ограничения
                            на культуру формирования входящих данных
            буфер должен быть агрегирован по сравниваемым параметрам (после этапа MVP возникнет как раз вопрос:
                DBT/CRD - например оплата и последующий возврат - даст в итоге нулевую проводку в системе
                    на текущем этапе - требование к пользователю разделять по CARRY_GROUND
        SRC - буфер, который набрали из FCT (для сравнения)
                поле даты для отбора правильнее брать из TGT, набор по интервалу,
                затем подготовка таблицы с переписыванием поля дат (приведение к единому формату с TGT)
        Основное условие идентификации проводки:
            совпдает по клинету/счёту/договору/дате/VL/CARRY_GROUND/extra_data & IS_DEL (используем как признак первичного набора)
                присутствует в TGT и SRC: без обработки
                отсутствует в TGT но есть в SRC - INSERT (что-то новенькое загрузили)
                есть в TGT но отсутствует в SRC - INSERT СТОРНО
                    (видимо проводку удалил или скорректировал пользователь - ошибочная или ещё почему-то)
        Примечание: логика грубая, может плодить много мусорных записей если пользователь активно корректирует данные
            однако сохраняет историю изменений, при должно аккуратности при подготовке данных вполне себе
            возможны сбои при обработке 2 полностью идентичных проводок - агрегировать на этапе подготовки данных буфера
            необходимо будет уточнять после этапа MVP

        все INSERTы без флага IS_DEL
*/



--собираем идентификаторы
--формируем буфер TGT
    ;with CTE as
    (       select
--                  cb.LOAD_DATE
                , cb.CARRY_DATE
                , cb.turnover
                , cb.account_name
                , da.id_account
                , cb.bal2
                , cb.agreement_name
                , dac.id_agreement
                , cb.client_name
                , dc.id_client
                , cb.carry_ground
                , cb.extra_data
            FROM #carry_buffer cb
            left join dic_client dc on dc.client_name = cd.client_name
            left join dic_agreement da on dc.agreement_name = da.agreement_name
            left join dic_account dac on dc.account_name = dac.account_name
    )
    UPDATE #carry_buffer tgt
    SET
        , id_account      = c.id_account
        , id_agreement    = c.id_agreement
        , id_client       = c.id_client
    FROM CTE c
    WHERE 1=1
        and
        c.account_name = tgt.account_name
        and
        c.agreement_name = tgt.agreement_name
        and
        c.client_name = tgt.client_name
    GO;

    --разметка IS_DEL
    UPDATE #carry_buffer tgt
    SET tgt.IS_DEL = 1
    WHERE 1=1


    --дата начала периода
    --дата конца периода
    declare @processing_perion_start date = datefromparts(@YEAR, @MONTH, 1);
    declare @processing_perion_end date = eomonth(@processing_perion_start);

    --набор действующих проводок
    drop table if exists #carry_bufffer_real;
    select *
    into #carry_bufffer_real
    FROM #FCT_CARRY fc
    WHERE
        fc.carry_date >= @processing_perion_start
        and
        fc.carry_date <= @processing_perion_end
    GO;

    MERGE #carry_buffer & #carry_bufffer_real
    ON id_account id_agreement id_client
    сравнение - целевая (таблица в базе), источник (входящий буфер)
    совпадатает полностью & оборото - ничего не делаем
    совпадает полностью но не оборот -
        убрать метку DEL ??? перепутана разметка источника и буфера??? пвторный анализ алгоритма
        добавить сторнирующую
        до бавить новую
    не нашлось в источнике - добавить
--сверка наборов, создание набора для записи, разметка

-- отбрасываем все для удаления

-- запись оставшихся в целевую таблицу

END
