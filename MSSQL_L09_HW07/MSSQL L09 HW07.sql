/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "07 - Динамический SQL".

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

Это задание из занятия "Операторы CROSS APPLY, PIVOT, UNPIVOT."
Нужно для него написать динамический PIVOT, отображающий результаты по всем клиентам.
Имя клиента указывать полностью из поля CustomerName.

Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+----------------+----------------------
InvoiceMonth | Aakriti Byrraju    | Abel Spirlea       | Abel Tatarescu | ... (другие клиенты)
-------------+--------------------+--------------------+----------------+----------------------
01.01.2013   |      3             |        1           |      4         | ...
01.02.2013   |      7             |        3           |      4         | ...
-------------+--------------------+--------------------+----------------+----------------------
*/


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

declare @request_str3 nvarchar(MAX) --строковый литерал для формирования запроса
--параметры
declare @columns_list3 nvarchar(max)
select @columns_list3 = 
		string_agg( convert(nvarchar(max), quotename(CustomerName)), ',')
				within group (order by CustomerName)
FROM Sales.Customers
--demo
print @columns_list3

--основной запрос
set @request_str3 = N'	
	select * 
	from (
		select
			sc.CustomerName as ClientName,
			format(datetrunc(month, si.InvoiceDate),''dd.MM.yyyy'') as InvoiceMonth,
			count(si.InvoiceID) as Invoices_in_month
		from Sales.Invoices si
		left join Sales.Customers sc on sc.CustomerID = si.CustomerID
		group by
			sc.CustomerName,
			format(datetrunc(month, si.InvoiceDate),''dd.MM.yyyy'')
		) as s
	PIVOT (
		sum(Invoices_in_month)
		for ClientName in ('+	 @columns_list3 + ')
		) as pvt
	Order by pvt.InvoiceMonth
				'--литерал закончился

--demo
print @request_str3

--выполнение запроса
exec sp_executesql @request_str3


/* CTE в чистом виде
		select
			sc.CustomerName as ClientName,
			format(datetrunc(month, si.InvoiceDate),'dd.MM.yyyy') as InvoiceMonth,
			count(si.InvoiceID) as Invoices_in_month
		from Sales.Invoices si
		left join Sales.Customers sc on sc.CustomerID = si.CustomerID
		where sc.CustomerID between 2 and 6
		group by
			sc.CustomerName,
			format(datetrunc(month, si.InvoiceDate),'dd.MM.yyyy')
*/