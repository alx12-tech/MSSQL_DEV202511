/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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

USE WideWorldImporters

/*
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/

--полный перечень имён клиентов (в виде подзапроса в PIVOT не поддерживается)
	select 
		--sc.CustomerID,
		substring(sc.CustomerName, 
					charindex('(', sc.CustomerName, 1) + 1,
					charindex(')', sc.CustomerName, charindex('(', sc.CustomerName, 1)) - charindex('(', sc.CustomerName, 1) - 1
					) as [Подстрока]
	from Sales.Customers sc 
	where sc.CustomerID between 2 and 6
------------------

;with subrequest as
(
--сводка покупок в разрезе клиентов (первичная статистика)
	select
		--sc.CustomerName as ClientName,
		substring(sc.CustomerName, 
						charindex('(', sc.CustomerName, 1) + 1,
						charindex(')', sc.CustomerName, charindex('(', sc.CustomerName, 1)) - charindex('(', sc.CustomerName, 1) - 1
						) as ClientName,
		format(datetrunc(month, si.InvoiceDate),'dd.MM.yyyy') as InvoiceMonth,
		count(si.InvoiceID) as Invoices_in_month
	from Sales.Invoices si
	left join Sales.Customers sc on sc.CustomerID = si.CustomerID
	where sc.CustomerID between 2 and 6
	group by 
		sc.CustomerName,
		format(datetrunc(month, si.InvoiceDate),'dd.MM.yyyy')
)
--select * from ClientNames--в секции FOR не поддерживаются подзрапросы, формируем строки
select * from subrequest s
PIVOT (
	sum(Invoices_in_month)
	for ClientName in (	 [Sylvanite, MT]
						,[Peeples Valley, AZ]
						,[Medicine Lodge, KS]
						,[Gasport, NY]
						,[Jessie, ND]
						) 
	) as pvt
Order by pvt.InvoiceMonth

--приведение формата даты к первому месяцу
select format(datetrunc(month, getdate()),'dd.MM.yyyy')

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/
;with subreq as
	(
	select distinct
		sc.CustomerName,
		sc.DeliveryAddressLine1,
		sc.DeliveryAddressLine2,
		sc.PostalAddressLine1,
		sc.PostalAddressLine2
	from Sales.Invoices si
	left join Sales.Customers sc on sc.CustomerID = si.CustomerID
	where sc.CustomerName like '%Tailspin Toys%'
)

select 
	CustomerName	--сохр.источник
	,AddressLine	--приводимые значения
--	,AddrTypes		--приводимые имена
FROM subreq sr
UNPIVOT (
	AddressLine			--приводимые значения
	FOR AddrTypes in	--список приводимых имён
		(
			DeliveryAddressLine1,
			DeliveryAddressLine2,
			PostalAddressLine1,
			PostalAddressLine2
		) 
	) as unpvt
ORDER by 1
	


/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

;with subreq as
(
	select
		 ap.CountryID
		,ap.CountryName
		,cast(ap.[IsoAlpha3Code] as varchar(128)) as [IsoAlpha3Code]
		,cast(ap.IsoNumericCode as varchar(128)) as IsoNumericCode
	from Application.Countries ap
)

select 
	CountryID
	,CountryName
	,Code
from subreq sr
UNPIVOT (
	Code
	FOR CodeTypes IN (
			[IsoAlpha3Code],
			[IsoNumericCode]
		)
	) unpvt
order by 1




/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/
drop table if exists #subreq;

select distinct
	 sc.CustomerID		as IDClient
	,sc.CustomerName	as ClientName
	,sil.StockItemID	as StockItemID
	,sil.UnitPrice		as UnitPrice
	,dense_rank() over (partition by sc.CustomerID order by sil.UnitPrice desc) as PriceRank
	,dense_rank() over (partition by sc.CustomerID, sil.StockItemID order by si.InvoiceDate desc) as DateRank
	,si.InvoiceDate		as InvoiceDate
into #subreq--закоментировать для отладки
from Sales.InvoiceLines sil
left join Sales.Invoices si			on si.InvoiceID = sil.InvoiceID
left join Sales.Customers sc		on sc.CustomerID = si.CustomerID
/*--раскоментировать для отладки, проверка результата
ORDER BY	 IDClient		asc
			,UnitPrice		desc
			,InvoiceDate	desc
			,StockItemID	asc
*/
--в результирующую выборку по клиенту ranks in (1,1), (2,1), товар - прицепом


select distinct
	 sc.CustomerID			as [Идентификатор покупателя]
	,sc.CustomerName		as [Наименование покупателя]
	,top_price.StockItemID	as [Идентификатор товара]
	,wsi.StockItemName		as [Наименование товара]
	,top_price.Price		as [Макс.цена товара у покупателя]
	,top_price.InvoiceDate	as [Посл.дата тов.по макс.цене]
from Sales.Customers sc--исходим из приницпа - все клиенты представлены в справочнике
CROSS APPLY (
	SELECT
		srq.StockItemID,
		srq.UnitPrice as Price,
		srq.InvoiceDate
	from #subreq srq--здесь размечены нужные инвойсы
	where	srq.IDClient = sc.CustomerID
		and srq.PriceRank in (1, 2)
		and srq.DateRank = 1
	) top_price
left join Warehouse.StockItems wsi	on wsi.StockItemID = top_price.StockItemID--наименование товара, чтобы не тащить через все таблицы
ORDER BY--представление для наглядности
	sc.CustomerID asc,
	top_price.Price desc


	/* OLD version
	drop table if exists #subreq;
select
	 sc.CustomerID		as IDClient
	,sc.Customername	as ClientName
	,sil.StockItemID	as StockItemID
--	,wsi.StockItemID	as StockItemID
--	,wsi.StockItemName	as StockItemName
	,sil.UnitPrice		as Price
	,si.InvoiceDate		as InvoiceDate
into #subreq
from Sales.InvoiceLines sil
left join Sales.Invoices si			on si.InvoiceID = sil.InvoiceID
left join Sales.Customers sc		on sc.CustomerID = si.CustomerID
--left join Warehouse.StockItems wsi	on wsi.StockItemID = sil.StockItemID--наименование на данном этапе некритично - подтянуть в финальной сборке
--select * from #subreq

select distinct
	sr.IDClient,
	sr.ClientName,
	top_price.StockItemID,
	wsi.StockItemName,
	top_price.Price,
	top_price.InvoiceDate
from #subreq sr
CROSS APPLY (
	select top 2 
		srq.StockItemID,
--		srq.StockItemName,
		srq.Price,
		srq.InvoiceDate
	from #subreq srq
	where srq.IDClient = sr.IDClient-- and srq.StockItemID = sr.StockItemID
	ORDER BY srq.Price desc
	) top_price
left join Warehouse.StockItems wsi	on wsi.StockItemID = top_price.StockItemID--наименование товара, чтобы не тащить через все таблицы
ORDER BY
	sr.IDClient asc,
	top_price.StockItemID asc,
	top_price.Price desc
	*/