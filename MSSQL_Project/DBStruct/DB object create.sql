/*
	Проект: База данных для управления личными финансами
	Этап проекта: 
		1. создание базы данных
		2. Создание базовых таблиц проекта
		2.1 Создание первичных ключей
		2.2 Учёт ограничений полей
		2.3 Создание индексов
*/

--------------------------------------------------------------------
-- 1. Создание базы данных
CREATE DATABASE PersonalFinance3
 ON  PRIMARY 
	( NAME = PF_vol, FILENAME = N'C:\DBase\PFDB3\PF_vol1.mdf' , 
		SIZE = 8MB , 
		MAXSIZE = 50Mb, 
		FILEGROWTH = 10MB )
 LOG ON 
	( NAME = PF_log, FILENAME =  N'C:\DBase\PFDB3\PF_log.ldf' , 
		SIZE = 8MB , 
		MAXSIZE = 10GB , 
		FILEGROWTH = 65536KB )
GO

--------------------------------------------------------------------
--2. Создание таблиц

USE PersonalFinance3;
GO
--создание схем
--схема для загрузки и подготовки данных
CREATE Schema STAGE;
GO
--основная рабочая схема, хранение, расчёты
CREATE Schema Accounting;
GO
--схема для отчётов, пользовательских витрин, кубов
CREATE Schema Reports;
GO

--------------------------------------------------------------------
--Создание таблиц

/*
    Назначение: хранение минимально необходимых данных по второй стороне сделки
       
*/

CREATE table Accounting.DIC_CLIENT (
     id_client int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,client_name varchar(512) not null
    ,create_date date not null
    ,valid_to date not null default '2099-01-01'
    ,is_del bit not null default 0
    )

/*
    Назначение: хранение минимально необходимых обобщённых данных по сделке
    Примечание: в перспективе станет верхнеуровневым справочником-представлением
        детализация по сделкам разного рода будет представлена в нижележащих справочниках
        потребуется расширение на несколько колонок для обеспечения связности и идентификации направления
*/
CREATE table Accounting.DIC_AGREEMENT (
     id_agreement int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,agreement_name varchar(512) not null
    ,create_date date not null
    ,valid_to date not null default '2099-01-01'
    ,is_del bit not null default 0
    )


/*  назначение: справочник счетов
    основная хранениям информация: 
        обозначние счёта (в идеале - 2-значное значение, может быть синтетическим)
        основной формат ХХХХХ (5 разрядов - балансовый счёт 2-го порядка)
                        для полных 20-значных порядок формирования в соотв.с правилами учёта
                        для синтетических - кодирование алфавитно-цифровое, описание формата отдельно
        внешние ключи: идентификатор принадлежности к клиенту, идентификатор балансового счета
        дата валидности - срок действия (будет использоваться в расчётах - счёт должен быть валиден в расчётном периоде)
*/
CREATE table Accounting.DIC_ACCOUNT (
     id_account int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,account_name varchar(20) not NULL 
    ,id_client int not NULL 
    ,accunt_description varchar(512) not NULL 
    ,id_bal2 int not NULL 
    ,valid_to date not NULL default '2099-01-01'

     FOREIGN KEY (id_account) REFERENCES Accounting.DIC_CLIENT(id_client),
     FOREIGN KEY (id_bal2) REFERENCES Accounting.DIC_BAL2(id_bal2)
    )


--Проводка (основной поток данных, все поля обязательные)
CREATE table  Accounting.FCT_CARRY
(
     id_CARRY int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,carry_date DATE            NOT NULL
    ,[description] varchar(512) NOT NULL
    ,id_account_dbt int         NOT NULL
    ,id_account_crd int         NOT NULL
    ,id_agreement int           NOT NULL
    ,VL float                   NOT NULL
    ,transaction_way int        NOT NULL
    ,SRC_date datetime          NOT NULL

     FOREIGN KEY (id_account_dbt) REFERENCES Accounting.DIC_ACCOUNT(id_account),
     FOREIGN KEY (id_account_crd) REFERENCES Accounting.DIC_ACCOUNT(id_account),
     FOREIGN KEY (id_agreement) REFERENCES Accounting.DIC_AGREEMENT(id_agreement)
)

/*
    Остаток на дату (таблица заполняемая расчётными процедурами)
    таблица историзации результатов расчётов
        без ключа - однозначного признака здесь нет
        без индекса - индексировать там нечего - это результаты расчётов которые ежедневно дополняются
*/
CREATE table  Accounting.DM_REST
(
      id_date   date  NOT NULL
    , id_account int  NOT NULL
    , val_nat   float NOT NULL

    FOREIGN KEY (id_account) REFERENCES Accounting.DIC_ACCOUNT(id_account),
)

--Классификаторы
--справочник версий (пока с базовым планом счетов)
CREATE table  Accounting.DIC_BAL2_VERSION
(
      id_bal2_version int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    , version_name varchar(1024) NOT NULL
    , is_del bit NOT NULL default 0
)


--Справочник балансовых счетов, версионный
CREATE table  Accounting.DIC_BAL2
(
     id_bal2 int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
--    ,[level] int not null default 1
    ,[name] varchar (5) not null--по стандарту 5-значный
    ,[description] varchar(512) not null
    ,id_bal2_parent int not null
    ,valid_to date not null default '2099-01-01'
    ,id_del bit NOT NULL default 0
    ,id_bal2_version int NOT NULL

    FOREIGN KEY (id_bal2_version) REFERENCES Accounting.DIC_BAL2_VERSION(id_bal2_version),
)




------------------------
--наполнение таблиц (первичное)

--дефолтный план счетов
insert into Accounting.DIC_BAL2_VERSION 
(version_name)
values
('706')
--chk
select * from Accounting.DIC_BAL2_version


--базовые расчётные счета
insert into Accounting.DIC_BAL2 (
     [name]
    ,[description]
    ,id_bal2_parent
    ,id_bal2_version
    )
values
--нулевая строка
('*',  'План счетов верхний уровень',                   1, 1),
('60', 'Расчёты с поставщиками и подрядчиками',         1, 1),
('62', 'Расчеты с покупателями и заказчиками',          1, 1),
('66', 'Расчеты по краткосрочным кредитам и займам',    1, 1),
('67', 'Расчеты по долгосрочным кредитам и займам',     1, 1),
('68', 'Расчеты по налогам и сборам',                   1, 1),
('79', 'Внутрихозяйственные расчеты',                   1, 1)
--
select * from Accounting.DIC_BAL2



--Схема STAGE
--на текущий момент реализована в объёме MVP
/*
    Наименование: буферна таблица загрузки приходно/расходных операций
    Бизнес-ограничения: загрузка должна включать все операции за рассматриваемый период
        иначе расчётные процедуры сгенерируют некорректный результат
    
    операционные свойства:
        неиндексируемая (зачем индексировать буфер? к нему обращаются 1 раз)
        не имеет первичного ключа (в этом нет смысла)
        очищаемая после обработки
        не допускает NULL (для упрощения процедур)
        не содержит внешних ключей (иначе будет ужас при загрузке), 
            ошибки проверяются процедурами-обработчиками при подготовке данных для передачи на расчётный слой
*/

CREATE table  STAGE.BUF_FCT_CARRY
(
     carry_date date           NOT NULL --дата проводки
    ,account_name varchar(20) NOT NULL  -- наименование счёта, проверку в XLS встроить проще
    ,agreement_name varchar(512) NOT NULL--наименование договора
    ,carry_ground varchar(512) not null --основание для проводки (транслируется в поле description FCT_CARRY)
    ,bal2_parent varchar(5) NOT NULL --балансовый счёт первичного учёта (в итоге должен быть привязан к ID_BAL2)
    ,extra_data varchar(512) NOT NULL default ''--поле дополнительных признаков, может быть пустое в общем случае
)