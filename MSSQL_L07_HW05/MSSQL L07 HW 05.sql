/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "06 - Оконные функции".

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
1. Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года 
(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
Выведите: id продажи, название клиента, дату продажи, сумму продажи, сумму нарастающим итогом

Пример:
-------------+----------------------------
Дата продажи | Нарастающий итог по месяцу
-------------+----------------------------
 2015-01-29   | 4801725.31
 2015-01-30	 | 4801725.31
 2015-01-31	 | 4801725.31
 2015-02-01	 | 9626342.98
 2015-02-02	 | 9626342.98
 2015-02-03	 | 9626342.98
Продажи можно взять из таблицы Invoices.
Нарастающий итог должен быть без оконной функции.
*/

set statistics time on;

--наритог без оконки
--вычисление итога по месяцу
;with month_subtotal as
(
	select distinct
		year(si.InvoiceDate) as [Год],
		month(si.InvoiceDate) as [Месяц],
		eomonth(si.InvoiceDate) as [Месяц суммы],
		sum(sil.Quantity * sil.UnitPrice) as [Итог по месяцу]
	from Sales.InvoiceLines sil--базовая по продажам
		left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID --расширение по датам
		left join Sales.Customers sc on sc.CustomerID = si.CustomerID --расширение по клиентам 
	where si.InvoiceDate >= '2015-01-01'
	group by year(si.InvoiceDate), month(si.InvoiceDate), eomonth(si.InvoiceDate)
--	order by [Год], [Месяц]
),
subtotal as--наритог
(
	select
		[Год],
		[Месяц],
		ms.[Месяц суммы],
		(	select sum(ms2.[Итог по месяцу])
			from month_subtotal as ms2
			where ms2.[Месяц суммы] <= ms.[Месяц суммы]
		) as [Наритог]
	from month_subtotal ms
--	order by [Год], [Месяц]
),
InvoiceSum as
(
	select
		sil.InvoiceID,
		sum(sil.Quantity * sil.UnitPrice) as OrderSum
	from Sales.InvoiceLines sil
	group by sil.InvoiceID
)

--итоговый запрос
select distinct --исключаем повторы приехавшие из Lines по позициям
	si.InvoiceDate as [Дата продажи],
	sc.CustomerName as [Наименование клиента],
	si.InvoiceID as  [Идентификатор продажи],
	ism.OrderSum as [Сумма продажи],
	st.[Наритог] as [Наритог по месяцам]
from Sales.InvoiceLines sil--базовая по продажам
left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID --расширение по датам
left join Sales.Customers sc on sc.CustomerID = si.CustomerID --расширение по клиентам
left join InvoiceSum ism on ism.InvoiceID = sil.InvoiceID--суммы по инвойсу
left join subtotal st on st.[Месяц суммы] = eomonth(si.InvoiceDate)
where si.InvoiceDate >= '2015-01-01'
order by [Дата продажи], [Наименование клиента]

set statistics time off;

/*

(затронуто записей: 31440)
 Время работы SQL Server:
   Время ЦП = 4140 мс, затраченное время = 5072 мс.
*/

/* промежуточные проверочные результаты наритога (первые 2 CTE)
Год	Месяц	Месяц суммы	Наиртог
2015	1	2015-01-31	4401699.25
2015	2	2015-02-28	8597018.50
2015	3	2015-03-31	13125150.15
2015	4	2015-04-30	18198414.90
2015	5	2015-05-31	22679145.45
2015	6	2015-06-30	27194985.90
2015	7	2015-07-31	32350657.90
2015	8	2015-08-31	36288821.30
2015	9	2015-09-30	40951421.30
2015	10	2015-10-31	45443470.70
2015	11	2015-11-30	49532679.20
2015	12	2015-12-31	53991490.45
2016	1	2016-01-31	58439196.40
2016	2	2016-02-29	62444813.25
2016	3	2016-03-31	67090067.25
2016	4	2016-04-30	71653733.35
2016	5	2016-05-31	76624666.00
*/

-- ---------------------------------------------------------------------------

/*
2. Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
   Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
*/


--включение
set statistics time on;

;with subtotal1 as
(	select distinct
		eomonth(si.InvoiceDate) as [Дата месяца],
		sum(sil.Quantity * sil.UnitPrice) over (
			partition by eomonth(si.InvoiceDate) 
			order by eomonth(si.InvoiceDate) 
			range between unbounded preceding and unbounded following--тут проблема... криво упорядочивается
			) as [Итог по месяцу]
	from Sales.InvoiceLines sil--базовая по продажам
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID --расширение по датам
	where si.InvoiceDate >= '2015-01-01'
--	order by [Дата месяца]
),
subtotal2 as
(	select	[Дата месяца],
			sum([Итог по месяцу]) over (order by [Дата месяца]) as [Наритог]
	from subtotal1
)

--select * from subtotal2 order by [Дата месяца]

select distinct --исключаем повторы приехавшие из Lines по позициям
	si.InvoiceDate as [Дата продажи],
	sc.CustomerName as [Наименование клиента],
	si.InvoiceID as  [Идентификатор продажи],
	sum(sil.Quantity * sil.UnitPrice) over (partition by sil.InvoiceID)  as [Сумма продажи],
	st2.Наритог as [Сумма наритогом по мес.]
from Sales.InvoiceLines sil--базовая по продажам
left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID --расширение по датам
left join Sales.Customers sc on sc.CustomerID = si.CustomerID --расширение по клиентам
left join subtotal2 st2 on st2.[Дата месяца] = EOMONTH(si.InvoiceDate)
where si.InvoiceDate >= '2015-01-01'
order by [Дата продажи], [Наименование клиента]


--выключение
set statistics time off;

/*
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 46 мс, истекшее время = 179 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 0 мс.

(затронуто записей: 31440)

 Время работы SQL Server:
   Время ЦП = 438 мс, затраченное время = 3478 мс.

Вывод: на полученнах запросах разница по времени выполнения ~2 раза
Что, учитывая использование виртуальной машины, не показательно
*/



-- ---------------------------------------------------------------------------
/*
3. Вывести список 2х самых популярных продуктов (по количеству проданных) 
в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
*/

--продажи помесячно по товарам
;with CTE as
(
	select distinct
		sil.StockItemID,
		wsi.StockItemName,
		month(si.InvoiceDate) as month_,
		sum(sil.Quantity) over (partition by sil.StockItemID, month(si.InvoiceDate) ) as [Количество]
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	left join WareHouse.StockItems wsi on wsi.StockItemID = sil.StockItemID
	where si.InvoiceDate between '2016-01-01' and '2016-12-31'
),
 
ordered_stock as
(
select
	c.StockItemID,
	c.StockItemName,
	c.month_,
	c.[Количество],
	row_number() over (partition by c.month_ order by [Количество] desc) as row_counter
from CTE c

)

select *
from ordered_stock os
where os.row_counter in (1,2)
order by os.month_, os.row_counter


/* check: какие месяцы вообще встречаются
	select distinct month(si.InvoiceDate) as month_
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	left join WareHouse.StockItems wsi on wsi.StockItemID = sil.StockItemID
	where si.InvoiceDate between '2016-01-01' and '2016-12-31'
*/

-- ---------------------------------------------------------------------------

/*
4. Функции одним запросом
Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
* пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
* посчитайте общее количество товаров и выведете полем в этом же запросе
* посчитайте общее количество товаров в зависимости от первой буквы названия товара
* отобразите следующий id товара исходя из того, что порядок отображения товаров по имени 
* предыдущий ид товара с тем же порядком отображения (по имени)
* названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
* сформируйте 30 групп товаров по полю вес товара на 1 шт

Для этой задачи НЕ нужно писать аналог без аналитических функций.
*/




select
	wsi.[StockItemID]
,	wsi.StockItemName
,	wsi.Brand
,	wsi.UnitPrice
,	dense_rank() over (partition by left(wsi.StockItemName, 1) order by wsi.StockItemName) as [Нумерация наименований по буквам]
,	count(*) over (order by wsi.StockItemID) as [Количество товаров]
,	count(*) over (partition by left(wsi.StockItemName, 1)) as [Количество по первым буквам]
,	lead(wsi.StockItemName, 1, 'No items') over (order by wsi.StockItemName) as [Следующий товар]
,	lag(wsi.StockItemName, 2, 'No items') over (order by wsi.StockItemName) as [Следующий товар]
,	ntile(30) over (order by wsi.[TypicalWeightPerUnit]) as [Группа удельного веса]
from [Warehouse].[StockItems] wsi
order by wsi.StockItemName asc

-- ---------------------------------------------------------------------------

/*
5. По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
   В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
*/

;with CTE as
(
	select
		ap.PersonID as [Идентификатор сотрудника],
		ap.FullName as [Фамилия сотрудника],
		sc.CustomerID as [Идентификатор клиента],
		sc.CustomerName as [Наименование клиента],
		si.InvoiceDate as [Дата продажи],
		sum(sil.Quantity * sil.UnitPrice) over (partition by sil.InvoiceID) as [Сумма сделки],
		dense_rank() over (partition by si.SalespersonPersonID order by si.InvoiceDate desc) as [Порядок продаж]
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	left join Sales.Customers sc on sc.CustomerID = si.CustomerID
	left join Application.People ap on ap.PersonID = si.SalespersonPersonID
)
select
	 [Идентификатор сотрудника]
	,[Фамилия сотрудника]
	,[Идентификатор клиента]
	,[Наименование клиента]
	,[Дата продажи]
	,[Сумма сделки]
from CTE c
where c.[Порядок продаж] =1
order by c.[Фамилия сотрудника]


-- ---------------------------------------------------------------------------

/*
6. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/


select distinct *
from 
(
	select
		sc.CustomerID as [Идентификатор клиента],
		sc.CustomerName as [Наименование клиента],
		sil.StockItemID as [Идентификатор товара],
		wsi.StockItemName	as [Наименование товара],
		sil.UnitPrice as [Цена товара],
		si.InvoiceDate as [Дата продажи],
		row_number() over (partition by si.CustomerID order by sil.UnitPrice desc, si.InvoiceDate desc) as [Упорядоченный список]
	from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	left join Sales.Customers sc on sc.CustomerID = si.CustomerID
	left join Warehouse.StockItems wsi on wsi.StockItemID = sil.StockItemID
) as temp
where [Упорядоченный список] in (1,2)
order by 
	[Идентификатор клиента],
	[Цена товара]
	






Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность. 