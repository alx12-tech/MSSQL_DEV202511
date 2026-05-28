/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

/* по причине различных подходов к исичслению понятия "цена товара" 
для рынков США (на котором построена БД) и РФ
принимаем модель РФ.
В связи с чем, для чего для целей исчисления цены товара будем использовать
значение поля ExtendedPrice, включающую все налоги и сборы
указанное поле рассчитано для кадой позиции (строки) счёта
таким образом в расчёте будет участововать: 
количество позиций в строке, итоговая стоимость строки для покупателя

средняя цена товара будет вычисляться как - полная стоимость товаров за период, 
отнесённая к количеству товаров за тот же преиод (сумма по полю Quantity)

*/

select	year(si.InvoiceDate) as date_year,
		month(si.InvoiceDate) as date_month,
		sum(sil.ExtendedPrice) as month_sum,
		sum(sil.ExtendedPrice) / sum(sil.Quantity) as month_mean_price
from Sales.InvoiceLines sil
	left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
group by
	year(si.InvoiceDate),
	month(si.InvoiceDate)
order by date_year, date_month


/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select *
from 
	(
	select	year(si.InvoiceDate) as date_year,
			month(si.InvoiceDate) as date_month,
			sum(sil.ExtendedPrice) as month_sum
	from Sales.InvoiceLines sil
		left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
	group by
		year(si.InvoiceDate),
		month(si.InvoiceDate)
	) pre_result
where pre_result.month_sum > 4.6e6
order by date_year, date_month


/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select
	date_year		as 'год продажи',
	date_month		as 'месяц продажи',
	StockItemName	as 'Наименование товара',
	month_sum		as 'Сумма за месяц',
	first_inv_date	as 'Первая продажа',
	month_Quantity	as 'Продано в мес.'
from (
	select	year(si.InvoiceDate)	as date_year,
			month(si.InvoiceDate)	as date_month,
			whsi.StockItemName		as StockItemName,
			sum(sil.ExtendedPrice)	as month_sum,
			min(si.InvoiceDate)		as first_inv_date,
			sum(sil.Quantity)		as month_Quantity
	from Sales.InvoiceLines sil
		left join Sales.Invoices si on si.InvoiceID = sil.InvoiceID
		left join WareHouse.StockItems whsi on whsi.StockItemID = sil.StockItemID
	group by
		year(si.InvoiceDate),
		month(si.InvoiceDate),
		whsi.StockItemName	
	) temp
where temp.month_Quantity < 50
order by
	date_year,
	date_month,
	StockItemName


-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/
