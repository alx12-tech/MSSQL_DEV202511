/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

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
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/
with CTE AS
(
	select 
		ap.PersonID,
		ap.FullName
	from Application.People ap
	where ap.IsSalesperson = 1
)

select c.*
from CTE c
full outer join Sales.Invoices si 
	on	si.SalespersonPersonID = c.PersonID 
		and si.InvoiceDate = '2015-07-04'
where si.InvoiceID is NULL


/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/


select top 10
	whsi.StockItemID,
	whsi.StockItemName,
	whsi.UnitPrice
from WareHouse.StockItems whsi
order by
	whsi.UnitPrice asc

--сильно неоптимально, но с подзапросом
select
	whsi.StockItemID,
	whsi.StockItemName,
	whsi.UnitPrice
from WareHouse.StockItems whsi
where whsi.StockItemID in 
	(
		select top 10 w.StockItemID
		from WareHouse.StockItems w
		order by w.UnitPrice asc
	)



/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

select 
	sc.CustomerCategoryID,
	sc.CustomerName,
	c.MaxAmount
from Sales.Customers sc
inner join 
	(
		select distinct top 5
		CustomerID,
		MaxAmount
		from
			(
				select 
					sct.CustomerID,
					max(sct.TransactionAmount) as MaxAmount
				from Sales.CustomerTransactions sct
				group by sct.CustomerID
			) a
		order by MaxAmount
	) c on c.CustomerID = sc.CustomerID
order by c.MaxAmount desc


-----
-- отбор уникальных закзачиков с максимальной транзакцией
with CTE as
(
	select distinct top 5
		CustomerID,
		MaxAmount
	from
		(
			select 
				sct.CustomerID,
				max(sct.TransactionAmount) as MaxAmount
			from Sales.CustomerTransactions sct
			group by sct.CustomerID
		) a
	order by MaxAmount
) 

select 
	sc.CustomerCategoryID,
	sc.CustomerName,
	c.MaxAmount
from Sales.Customers sc
inner join CTE c on c.CustomerID = sc.CustomerID
order by c.MaxAmount desc



/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

--логичекий план:
--отобрать заказы собранные
--выбрать 3 самых дорогих товара
--определить города доставки и заказы
--определить сотрудника который паковал заказы
--человекочитаемое название сотрудника?

--несобранные заказы
;with PickedOrders as
(	
	select so.OrderID
	from Sales.Orders so 
	where so.PickingCompletedWhen is NOT NULL
),
--товары в собранных заказах (исходим из оплаты покупателем - по счетам)
MaxPriceUnits as
(
	select top 3
		sil.StockItemID, max(sil.UnitPrice) as MaxUnitPrice
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID--привязка счета к заказу
	join PickedOrders po on po.OrderID = si.OrderID
	group by sil.StockItemID
	order by MaxUnitPrice desc
),
--собранные заказы с 3 товарами с макс.ценой
InvoicesWithMaxUnitPrices as
(
	select distinct sil.InvoiceID
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	inner join PickedOrders po on po.OrderID = si.OrderID
	inner join MaxPriceUnits mpu on mpu.StockItemID = sil.StockItemID
)
--основной запрос
select distinct
	ac.CityID,
	ac.CityName,
	ap.FullName as [Упаковщик]
from Sales.Invoices si
join InvoicesWithMaxUnitPrices iwup on si.InvoiceID = iwup.InvoiceID--фильтр заказов
left join Sales.Customers sc on sc.CustomerID = si.CustomerID--заказчик
left join Application.People ap on ap.PersonID = si.PackedByPersonID--упаковщик
left join Application.Cities ac on ac.CityID = sc.DeliveryCityID



-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 



-- 5. Объясните, что делает и оптимизируйте запрос

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	--прицеп продавцов
	(	SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	--полная сумма на счёте
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	--
	(	SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		--сбор заказа завершен
		WHERE OrderLines.OrderId = 
			(	SELECT Orders.OrderId 
				FROM Sales.Orders
				WHERE	Orders.PickingCompletedWhen IS NOT NULL	
					AND Orders.OrderId = Invoices.OrderId
			)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	--подзапрос собирающий счета с суммой больше 2700
	(	SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
		FROM Sales.InvoiceLines
		GROUP BY InvoiceId
		HAVING SUM(Quantity*UnitPrice) > 27000
	) AS SalesTotals
	ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC

-- --

--выбирает счета с суммой более 2700
--с завершенным выбором
--дополняет продавцов к счетам
--выводит сумму по счёту
--выводит сумму по выбраным позициям

/*	из очевидного направления оптимизации
		человекочитаемые наименования полей
		выделить в отдельные CTE или времянки подзапросы:
			сбор счетов с ограничением по сумме
			отбр завершенных по сбору заказов
		подзапрос в селекте перевести в основной join
TODO: напишите здесь свое решение
