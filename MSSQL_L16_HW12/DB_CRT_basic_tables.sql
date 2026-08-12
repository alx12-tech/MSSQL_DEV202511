/*
    Основные таблицы базы
*/

/*======================================================*/
--Базовые сущности



/*
    Назначение: хранение минимально необходимых данных по второй стороне сделки
       
*/
DROP table IF EXISTS  Accounting.DIC_CLIENT;

CREATE table Accounting.DIC_CLIENT (
     id_client      int         not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED--идентификатор клиента
    ,client_name    varchar(512) not null
    ,create_date    datetime2   not null default getdate()
    ,valid_to       datetime2   not null default '2099-01-01'--запредельная дата, возможно база до неё и доживёт
    ,is_del         bit         not null default 0
    )

--создание индексов
Create NONCLUSTERED Index DIC_CLIENT_INDEX ON Accounting.DIC_CLIENT(ID_CLIENT)
GO



/*
    Назначение: хранение минимально необходимых обобщённых данных по сделке
    Примечание: в перспективе станет верхнеуровневым справочником, объединяющим данные с разных направлений
        детализация по сделкам разного рода будет представлена в нижележащих справочниках, учитывающих специфику направления
        потребуется расширение на несколько колонок для обеспечения связности и идентификации направления
*/
DROP table IF EXISTS Accounting.DIC_AGREEMENT

CREATE table Accounting.DIC_AGREEMENT (
     id_agreement   int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,agreement_name varchar(512) not null
    ,create_date    datetime2 not null default getdate()
    ,valid_to       datetime2 not null default '2099-01-01'
    ,is_del         bit not null default 0
    )

--создание индексов
Create NONCLUSTERED Index DIC_AGREEMENT_INDEX ON Accounting.DIC_AGREEMENT(id_agreement)
GO


/*  назначение: справочник счетов
    основная хранениям информация: 
        обозначние счёта (в идеале - 2-значное значение, может быть синтетическим)
        основной формат ХХХХХ (5 разрядов - балансовый счёт 2-го порядка)
                        для полных 20-значных порядок формирования в соотв.с правилами учёта
                        для синтетических - кодирование алфавитно-цифровое, описание формата отдельно
        внешние ключи: идентификатор принадлежности к клиенту, идентификатор балансового счета
        дата валидности - срок действия (будет использоваться в расчётах - счёт должен быть валиден в расчётном периоде)
*/


/*======================================================*/
DROP table IF EXISTS Accounting.DIC_ACCOUNT;

CREATE table Accounting.DIC_ACCOUNT (
     id_account     int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,account_name   varchar(20) not NULL --жесткое ограничение на обозначение счёта, наименование обязательно
    ,id_client      int not NULL 
    ,accunt_description varchar(512) not NULL 
    ,id_bal2        int not NULL--для пользовательских счетов этапа MVP возникла проблема автоматической классификации (вынесено в процедуру наполнениея)
    ,valid_to       datetime2 not NULL default '2099-01-01'

     FOREIGN KEY (id_account) REFERENCES Accounting.DIC_CLIENT(id_client),
     FOREIGN KEY (id_bal2) REFERENCES Accounting.DIC_BAL2(id_bal2)
    )

--создание индексов
--DROP INDEX IF EXISTS DIC_ACCOUNT_INDEX ON Accounting.DIC_ACCOUNT(id_account);
Create NONCLUSTERED Index DIC_ACCOUNT_INDEX ON Accounting.DIC_ACCOUNT(id_account)
GO

select * from Accounting.DIC_BAL2


---------------------------------------------------------
--Хранение основных фактов (проводки, остатки)

--Проводка (основной поток данных, все поля обязательные)
DROP table IF EXISTS Accounting.FCT_CARRY;

CREATE table  Accounting.FCT_CARRY
(
     id_CARRY int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,carry_date DATEtime2       NOT NULL--факт.дата проводки из учётнной системы
    ,carry_ground varchar(1024) NOT NULL
    ,id_account int     NOT NULL--MVP этап, счёт основного пользователя системы
--    ,id_account_dbt int         NOT NULL--перспективная доработка
--    ,id_account_crd int         NOT NULL--перспективная доработка
    ,id_agreement int           NOT NULL--связка на клиента через договор
    ,VL numeric(28,12)          NOT NULL
--    ,transaction_way int        NOT NULL--метод доставки транзакции в систему
    ,SRC_date datetime          NOT NULL--дата поставки данных из источника

     FOREIGN KEY (id_account) REFERENCES Accounting.DIC_ACCOUNT(id_account),
--     FOREIGN KEY (id_account_dbt) REFERENCES Accounting.DIC_ACCOUNT(id_account),
--     FOREIGN KEY (id_account_crd) REFERENCES Accounting.DIC_ACCOUNT(id_account),
     FOREIGN KEY (id_agreement) REFERENCES Accounting.DIC_AGREEMENT(id_agreement)
)

--создание индексов
--DROP INDEX IF EXISTS FCT_CARRY_INDEX ON Accounting.FCT_CARRY(ID_CARRY);
--Create CLUSTERED Index FCT_CARRY_INDEX ON Accounting.FCT_CARRY(ID_CARRY)
--GO



/*
    Остаток на дату (таблица заполняемая расчётными процедурами)
        таблица историзирует результаты расчётов
        инкрементальное хранение
        
        основной подход деления данных - по иерархии типов 
            (тип выходных даннных расчётных процедур, 
                например 100 тип - верхнеуровневая иерархия всех типов входящих данных
                т.е. данные агрегированные на заданную дату под иерархией 100 типа (и входящих)
                будут отражать агрегированные остатки на заданную дату (с учётом всех многократных перезагрузок данных)
            )
            номера расчётов (id_calc) - для возможности отката ошибочных загрузок (например)
            номер корректировки (id_corr) - фактически идентификатор расчётной процедуры выполнившей запись
*/
--DROP table IF EXISTS  Accounting.DM_REST;
CREATE TABLE  Accounting.DM_REST
(
      id_period int not null--расчётный период
    , id_calc int not null--номер расчёта
    , id_corr      int not null
    , id_type      int not null
    , id_client    int not null
    , id_account   int not null
    , id_agreement int not null
    , [value] numeric(28,12) not null

    FOREIGN KEY (id_account) REFERENCES Accounting.DIC_ACCOUNT(id_account),
    FOREIGN KEY (id_client) REFERENCES Accounting.DIC_CLIENT(id_client),
    FOREIGN KEY (id_agreement) REFERENCES Accounting.DIC_AGREEMENT(id_AGREEMENT),
    FOREIGN KEY (id_type) REFERENCES Accounting.dic_type(id_type),
    FOREIGN KEY (id_corr) REFERENCES Accounting.dic_corr(id_corr),
    FOREIGN KEY (id_period) REFERENCES Accounting.dic_period(id_period),
    FOREIGN KEY (id_calc) REFERENCES Accounting.dic_calc(id_calc)
)

