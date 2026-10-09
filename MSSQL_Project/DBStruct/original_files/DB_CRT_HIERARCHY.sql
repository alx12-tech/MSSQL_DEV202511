/*
	Создание иерархических справочников
*/

-------------------------
-- справочники
--список типов
CREATE TABLE Accounting.DIC_TYPE 
(
      id_type int not NULL primary key clustered
    , [description] nvarchar(1024) not NULL
)
--базовое наполнение
truncate table Accounting.DIC_TYPE;

insert into Accounting.DIC_TYPE
(id_type, [description])
values
(100, 'Входные данные'),
(101, 'Ручная загрузка'),
(102, 'Загрузка XLS'),
(900, 'Расчёт плана')

--версии иерархических справочников
CREATE TABLE Accounting.DIC_TYPE_HIERARCHY_VERSION
(
      id_version int not NULL primary key clustered
    , [description] nvarchar(1024) not NULL
)
--на этапе MVP только 1 иерархия
insert into Accounting.DIC_TYPE_HIERARCHY_VERSION
(id_version, [description])
values
(1, 'Основная версия справочника')

--иерархия типов
CREATE TABLE Accounting.DIC_TYPE_HIERARCHY
(
        id_type_hierarchy int not null IDENTITY(1,1) primary key clustered --сурргоатный ключ
    ,   id_version int not NULL--версия справочника
    ,   id_type int not NULL--идентификатор типа в иерархии
    ,   parent_id int--идентификатор вышестоящего узла (модет быть NULL для верхнего уровня)

    FOREIGN KEY (id_version) REFERENCES Accounting.dic_type_hierarchy_version(id_version),
    FOREIGN KEY (id_type) REFERENCES Accounting.DIC_TYPE(id_type),
    FOREIGN KEY (parent_id) REFERENCES Accounting.DIC_TYPE(id_type)
)
GO

insert into Accounting.DIC_TYPE_HIERARCHY
(id_version, id_type, parent_id)
values
(1, 100, NULL),
(1, 900, NULL),
(1, 101, 100),
(1, 102, 100)

----------------------------------------------------------------------------

--Классификаторы
--справочник версий (пока с базовым планом счетов)
DROP table IF EXISTS Accounting.DIC_BAL2_VERSION;

CREATE table  Accounting.DIC_BAL2_VERSION
(
      id_bal2_version int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    , version_name varchar(1024) NOT NULL
    , is_del bit NOT NULL default 0
)



/*======================================================*/
--Справочник балансовых счетов, версионный
CREATE table  Accounting.DIC_BAL2
(
     id_bal2            int not NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
--    ,[level] int not null default 1
    ,[name]             nvarchar (5) not null--по стандарту 5-значный
    ,[description]      nvarchar(512) not null
    ,id_bal2_parent     int not null
    ,valid_to           datetime2 not null default '2099-01-01'
    ,id_del             bit NOT NULL default 0
    ,id_bal2_version    int NOT NULL

    FOREIGN KEY (id_bal2_version) REFERENCES Accounting.DIC_BAL2_VERSION(id_bal2_version),
)



/*======================================================*/
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


----------------------------
--корректировки
DROP TABLE IF EXISTS Accounting.dic_corr

CREATE table Accounting.dic_corr (
        id_corr int not NULL PRIMARY KEY CLUSTERED--значение уникально, но не автоикрементируемо, таблица в общем случае заполняется вручную
      , [description] nvarchar(1024) --описание корректировки
      , [procedure_name] nvarchar(1024)--привязка к процедуре (чисто информативная)
)
