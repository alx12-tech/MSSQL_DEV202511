/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "08 - Выборки из XML и JSON полей".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters;

/*
Примечания к заданиям 1, 2:
* Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML. 
* Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
* Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
* Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server
*/


/*
1. В личном кабинете есть файл StockItems.xml.
Это данные из таблицы Warehouse.StockItems.
Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice 

Загрузить эти данные в таблицу Warehouse.StockItems: 
существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName). 

Сделать два варианта: с помощью OPENXML и через XQuery.
*/

/********************XPATH******************/

--чтение файла в переменную XML-типа
DECLARE @xmlDocument XML;
SELECT @xmlDocument = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\Alex\Desktop\HW\StockItems-188-1fb5df.xml', SINGLE_CLOB) as t
DECLARE @docHandle INT;--привязка к указателю
EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlDocument;--связывание
drop table if exists #temp_XML_VAR_table--времянка для результата разбора XML
--раскладка в таблицу по уровню Items
SELECT *
INTO #temp_XML_VAR_table
FROM OPENXML(@docHandle, N'/StockItems/Item') --путь от корня до разбираемого элемента
WITH ( --параметры функции OPENXML
	StockItemName nvarchar(512)  '@Name', -- имя атрибута, идентификатор служебный
    --основные поля таблицы, структура относительно заданного выше базового элемента
	[SupplierID] INT 'SupplierID', -- элемент по имени
	UnitPackageID int 'Package/UnitPackageID',--элементы на уровень ниже
    OuterPackageID int 'Package/OuterPackageID',
    QuantityPerOuter int 'Package/QuantityPerOuter',
    TypicalWeightPerUnit float 'Package/TypicalWeightPerUnit',
    LeadTimeDays int 'LeadTimeDays',
    IsChillerStock int 'IsChillerStock',
    TaxRate float 'TaxRate',
    UnitPrice float 'UnitPrice'
    )--with block end
-- удаляем указатель
EXEC sp_xml_removedocument @docHandle;
-- демо состояния переменных
--SELECT @docHandle AS docHandle, @xmlDocument AS [@xmlDocument];

--Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
select * from #temp_XML_VAR_table
/*  Загрузить эти данные в таблицу Warehouse.StockItems: 
        существующие записи в таблице обновить, 
        отсутствующие добавить (сопоставлять записи по полю StockItemName). 

    WareHouse.StockItems анализ списка полей:

    PK  StockItemID -> auto
    +   StockItemName
    +   SupplierID
    -   ColorID default NULL
    +   UnitPackageID
    +   OuterPackageID
    -   Brand   default NULL
    -   Size    default NULL
    +   LeadTimeDays
    +   QuantityPerOuter
    +   IsChillerStock
    -   Barcode default NULL
    +   TaxRate
    +   UnitPrice
    -   RecommendedRetailPrice default NULL
    +   TypicalWeightPerUnit
    -   MarketingComments default NULL
    -   InternalComments default NULL
    -   Photo default NULL
    -   CustomFields default NULL
    a   Tags default NULL
    a   SearchDetails nvarchar -> ''
    ?   LastEditedBy 
    ?   ValidFrom 
    ?   ValidTo   
*/

--MERGE #temp_WareHouse_StockItems_copy as TGT
MERGE WareHouse.StockItems as TGT
USING #temp_XML_VAR_table as SRC
	on tgt.StockItemName = src.StockItemName
when MATCHED --совпадение по наименованию
	then UPDATE set 
			SupplierID			 = src.SupplierID
		,	UnitPackageID		 = src.UnitPackageID
		,	OuterPackageID		 = src.OuterPackageID
		,	QuantityPerOuter	 = src.QuantityPerOuter
		,	TypicalWeightPerUnit = src.TypicalWeightPerUnit 
		,	LeadTimeDays		 = src.LeadTimeDays
		,	IsChillerStock		 = src.IsChillerStock
		,	TaxRate				 = src.TaxRate
		,	UnitPrice			 = src.UnitPrice
        ,   LastEditedBy         = 1--
when NOT MATCHED by target--новые по отношению к целевой
	then INSERT (
        StockItemName
    ,   SupplierID
    ,   UnitPackageID
    ,   OuterPackageID
    ,   LeadTimeDays
    ,   QuantityPerOuter
    ,   IsChillerStock
    ,   TaxRate
    ,   UnitPrice
    ,   TypicalWeightPerUnit
    ,   LastEditedBy  --default value use
				)
		values (        src.StockItemName
					,   src.SupplierID
                    ,   src.UnitPackageID
                    ,   src.OuterPackageID
                    ,   src.LeadTimeDays
                    ,   src.QuantityPerOuter
                    ,   src.IsChillerStock
                    ,   src.TaxRate
                    ,   src.UnitPrice
                    ,   src.TypicalWeightPerUnit
                    ,   1--LastEditedBy
				)
output $action, deleted.*, inserted.*
;


----------------------------------------------------------------------
/***************** + в формате XQuery+ ****************/

--считывание файла
DECLARE @xmldata XML;
SET @xmldata = (
		SELECT *
		FROM OPENROWSET(BULK 'C:\Users\Alex\Desktop\HW\StockItems-188-1fb5df.xml', SINGLE_CLOB) as t
		)
--select @xmldata
SELECT 
	    StockItemName = ltrim(rtrim(tmp.Item.value('(@Name)[1]', 'nvarchar(512)'))) -- имя атрибута, идентификатор служебный
    --основные поля таблицы
	,   [SupplierID] = tmp.Item.value('(SupplierID)[1]', 'INT') -- элемент по имени
	,   UnitPackageID = tmp.Item.value('(Package/UnitPackageID)[1]', 'INT')--элементы на уровень ниже
    ,   OuterPackageID = tmp.Item.value('(Package/OuterPackageID)[1]', 'INT')--элементы на уровень ниже
    ,   QuantityPerOuter = tmp.Item.value('(Package/QuantityPerOuter)[1]', 'INT')--элементы на уровень ниже
    ,   TypicalWeightPerUnit = tmp.Item.value('(Package/TypicalWeightPerUnit)[1]', 'float')--элементы на уровень ниже
    ,   LeadTimeDays = tmp.Item.value('(LeadTimeDays)[1]', 'INT')
    ,   IsChillerStock = tmp.Item.value('(IsChillerStock)[1]', 'INT')
    ,   TaxRate = tmp.Item.value('(TaxRate)[1]', 'float')
    ,   UnitPrice = tmp.Item.value('(UnitPrice)[1]', 'float')
from @xmldata.nodes('/StockItems/Item') as tmp(Item)

GO 


----------------------------------------------------------------------------------------
--************************************************************************************--
----------------------------------------------------------------------------------------

/*
2. Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
*/
--service 
EXEC sp_configure 'show advanced options', 1;
--
RECONFIGURE; 
GO
EXEC sp_configure 'xp_cmdshell', 1;
GO
RECONFIGURE; 
GO
--select @@

--подготовка данных для экспорта
IF OBJECT_ID('tempdb..##XmlExportTable') IS NOT NULL DROP TABLE ##XmlExportTable;
--
SELECT CAST((
    SELECT
          StockItemName as [@ItemName]
    --основные поля таблицы, структура относительно заданного выше базового элемента
        , [SupplierID] as [SupplierID]
        , UnitPackageID as [Package/UnitPackageID]
        , OuterPackageID as [Package/OuterPackageID]
        , QuantityPerOuter as [Package/QuantityPerOuter]
        , TypicalWeightPerUnit as [Package/TypicalWeightPerUnit]
        , LeadTimeDays [LeadTimeDays]
        , IsChillerStock [IsChillerStock]
        , TaxRate [TaxRate]
        , UnitPrice [UnitPrice]
    FROM WareHouse.StockItems
    FOR XML PATH('Item'), ROOT('StockItems')
) AS NVARCHAR(MAX)) AS XmlString
INTO ##XmlExportTable;
GO
--экспорт
DECLARE @command2exec varchar(4096);
set @command2exec = concat(
	    'bcp '--command
    ,   ' "SELECT XmlString FROM ##XmlExportTable"'--запрос на формирование данных
	,   ' queryout'--option key
	,   ' "C:\temp\MSSQL_L11_HW09_WHSI.XML"' --filename
	,   ' -T -w -t$%#@~'--options
	,   ' -S '--servername option
	,   @@servername--servername value
	);
print @command2exec;
exec master..xp_cmdshell @command2exec;


IF OBJECT_ID('tempdb..##XmlExportTable') IS NOT NULL DROP TABLE ##XmlExportTable;
--зачистка
DROP TABLE ##XmlExportTable;
GO


/*
3. В таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
Написать SELECT для вывода:
- StockItemID
- StockItemName
- CountryOfManufacture (из CustomFields)
- FirstTag (из поля CustomFields, первое значение из массива Tags)
*/

SELECT
        whsi.StockItemID
    ,   whsi.StockItemName
    ,   t.*
    ,   CustomFields
FROM Warehouse.StockItems whsi
outer apply openjson(CustomFields) with (
	CountryOfManufacture nvarchar(20) '$.CountryOfManufacture'
	, Tag1 nvarchar(20) '$.Tags[0]'
	) t

/*
4. Найти в StockItems строки, где есть тэг "Vintage".
Вывести: 
- StockItemID
- StockItemName
- (опционально) все теги (из CustomFields) через запятую в одном поле


Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.

Должно быть в таком виде:
... where ... = 'Vintage'

Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%' 
*/


SELECT 
    whsi.StockItemID,
    whsi.StockItemName,
    Tags.AllTags
FROM Warehouse.StockItems whsi
CROSS APPLY (
    SELECT STRING_AGG(value, ', ') AS AllTags
    FROM OPENJSON(whsi.CustomFields, '$.Tags')
) Tags
WHERE EXISTS (
    SELECT 1 
    FROM OPENJSON(whsi.CustomFields, '$.Tags') 
    WHERE value = 'Vintage'
);

/* demo
select top 10 whsi.Customfields
FROM Warehouse.StockItems whsi
where whsi.customfields like '%Vintage%'
*/
