/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, JOIN".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД WideWorldImporters можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/

select	wsi.StockItemID,
		wsi.StockItemName
from Warehouse.StockItems as wsi
where
	wsi.StockItemName like '%urgent%'
	OR
	wsi.StockItemName like 'Animal%'


/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

select distinct
	ps.SupplierID, ps.SupplierName
from Purchasing.Suppliers ps
left join Purchasing.PurchaseOrders ppo
	on ps.SupplierID = ppo.SupplierID
where ppo.SupplierID is NULL

--полный вариант
select distinct
	ps.SupplierID, ps.SupplierName
from Purchasing.Suppliers ps
full outer join Purchasing.PurchaseOrders ppo
	on ps.SupplierID = ppo.SupplierID
where ppo.SupplierID is NULL

--проверка / запрещённый вариант
/*
select distinct
	ps.SupplierID, ps.SupplierName
from Purchasing.Suppliers ps
where ps.SupplierID not in (select distinct ppo.SupplierID from  Purchasing.PurchaseOrders ppo )
*/



/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/

set Language Russian;

select
	sord.OrderID,
	sord.OrderDate,
	datename(month, sord.OrderDate) as 'Месяц', 
	datepart(quarter, sord.OrderDate) as 'Квартал',
	cast((month(sord.OrderDate) - 1)/4 as int)+1 as 'Треть',
	scst.CustomerName
from Sales.OrderLines sol 
left join Sales.Orders sord on sol.OrderID = sord.OrderID
left join Sales.Customers scst on scst.CustomerID = sord.CustomerID
where
	(sol.UnitPrice > 1000 and sol.Quantity > 20)
	OR sord.PickingCompletedWhen is not NULL
	 


/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

Select
	ps.SupplierName as 'Поставщик',
	adm.DeliveryMethodName as 'Способ доставки',
	ppo.ExpectedDeliveryDate as 'Дата поставки',
	ap.FullName as 'Принявший заказ'
from Purchasing.PurchaseOrders ppo
left join Purchasing.Suppliers ps on ps.SupplierID = ppo.SupplierID
left join Application.DeliveryMethods adm on adm.DeliveryMethodID = ps.DeliveryMethodID
--контактное лицо (наим.)
left join Application.People ap on ap.PersonID = ppo.ContactPersonID
where ppo.ExpectedDeliveryDate between  '2013-01-01' and '2013-01-31'
	and  ltrim(rtrim(adm.DeliveryMethodName)) in ('Air Freight', 'Refrigerated Air Freight')
	and ppo.IsOrderFinalized = 1
order by 
	ps.SupplierName
	, adm.DeliveryMethodName
	, ppo.ExpectedDeliveryDate 



/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

select top 10 with ties
	so.OrderID as 'Идентификатор заказа',
	so.OrderDate as 'Дата заказа',
	sc.CustomerName as 'Клиент',
	ap.FullName as 'Сотр.оформивший заказ'
from Sales.Orders so
	left join Sales.Customers sc on sc.CustomerID = so.CustomerID
	left join Application.People ap on ap.PersonID = so.SalespersonPersonID
order by
	so.OrderDate desc



/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

select
	sc.CustomerID as 'Идентификатор клиента в системе',
	sc.CustomerName as 'Имя клиента',
	sc.PhoneNumber as 'Номер телефона клиента'
from Sales.Orders so
	left join Sales.OrderLines sol on sol.OrderID = so.OrderID
	left join Sales.Customers sc on sc.CustomerID = so.CustomerID
	left join WareHouse.StockItems whsi on whsi.StockItemID = sol.StockItemID
where whsi.StockItemName = 'Chocolate frogs 250g'
order by sc.CustomerName