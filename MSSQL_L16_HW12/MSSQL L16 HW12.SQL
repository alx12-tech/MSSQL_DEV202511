/*
    Создание индексов для таблиц
    Рассматриваются таблицы:
    Схема	    Таблица
    Accounting	DIC_CLIENT
        Дополняется только при загрузке данных за период.
        Учитывая относительное "постоянство" финансового трека пользователя - обновляется медленно.
        При загрузке данных поиск выполняется по полю CLIENT_NAME для установления соответствия Client_ID
        При расчётах поиск выполняется по полю Client_ID (первичный ключ) - данный индекс будет использоваться намного чаще.
        Целесообразно индексировать поле ID_CLIENT со включением CLIENT_NAME
    Accounting	DIC_AGREEMENT
        Дополняется только при загрузке данных за период.
        Учитывая относительное "постоянство" финансового трека пользователя - обновляется медленно.
        При загрузке данных поиск выполняется по полю AGREEMENT_NAME для установления соответствия Agreement_ID
        При расчётах поиск выполняется по полю Agreement_ID (первичный ключ) - данный индекс будет использоваться намного чаще.
        Целесообразно индексировать поле Agreement_ID со включением AGREEMENT_NAME
    Accounting	DIC_ACCOUNT
        Дополняется только при загрузке данных за период.
        Учитывая относительное "постоянство" финансового трека пользователя - обновляется медленно.
        При загрузке данных поиск выполняется по полю ACCOUNT_NAME для установления соответствия ID_ACCOUNT
        При расчётах поиск выполняется по полю ID_ACCOUNT (первичный ключ) - данный индекс будет использоваться намного чаще.
        Целесообразно индексировать поле ID_ACCOUNT со включением ACCOUNT_NAME
    Accounting	FCT_CARRY
        Обновляется при расчётах, вероятно будет часто, т.к. планируется внедрение классификации по доп. признакам,
            планов и т.п., всё это будет создавать массу синтетических проводок.
        Основной поиск по ID_CARRY
        Целесообразен индекс по ID_CARRY, но перестроение вручную (по расписанию)
    Accounting	DM_REST
        Таблица фактов
        Наиболее частая фильтрация будет выполняться по (в порядке убывания частоты)
            - дате
            - клиенту
            - договору
            - счёту
        Больше подходит для секционирования таблицы чем для индекса. На первых этапах индексацию не применять.
    Accounting	DIC_BAL2_VERSION
        Таблица практически статична.
        Очень небольшого размера - индексация бессмысленна.
    Accounting  DIC_BAL2
        Таблица очень редко меняется
        Размер небольшой - индексация в н.в. не имеет смылса.
        В будущем возможно - по ID_BAL2 со включением BAL2_NAME, BAL2_VERSION (эти два поля работают только в связке)
    STAGE       BUF_FCT_CARRY
        Таблица входящий буфер - при работе изменяется в полном объёме.
        Индексировать бессмысленно.

*/

--создание индексов
DROP INDEX IF EXISTS DIC_CLIENT_INDEX ON Accounting.DIC_CLIENT(ID_CLIENT);
Create NONCLUSTERED Index DIC_CLIENT_INDEX ON Accounting.DIC_CLIENT(ID_CLIENT)
INCLUDE CLIENT_NAME ;
GO

DROP INDEX IF EXISTS
Create NONCLUSTERED Index DIC_AGREEMENT_INDEX ON Accounting.DIC_AGREEMENT()
INCLUDE AGREEMENT_NAME;
GO

DROP INDEX IF EXISTS DIC_ACCOUNT_INDEX ON Accounting.DIC_ACCOUNT();
Create NONCLUSTERED Index DIC_ACCOUNT_INDEX ON Accounting.DIC_ACCOUNT()
INCLUDE ACCOUNT_NAME;
GO

DROP INDEX IF EXISTS FCT_CARRY_INDEX ON Accounting.FCT_CARRY(ID_CARRY);
Create CLUSTERED Index FCT_CARRY_INDEX ON Accounting.FCT_CARRY(ID_CARRY)
ONLINE OFF
GO

