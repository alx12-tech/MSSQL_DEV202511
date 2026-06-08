/*
    Вебинар: 18 Хранимые процедуры, функции, триггеры, курсоры. ДЗ 
    ДЗ: N 13
	
1    Написать функцию возвращающую Клиента с наибольшей суммой покупки.
2    Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
    Использовать таблицы :
    Sales.Customers
    Sales.Invoices
    Sales.InvoiceLines
3    Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.
4    Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла.
5    Опционально. Во всех процедурах укажите какой уровень изоляции транзакций вы бы использовали и почему.

Критерии оценки:
Статус "Принято" ставится, если написаны SQL-запросы, выводящие правильные результаты в соответствии с заданиями.

*/




----------------------------------------------------------------------
/*  Задание 3
    Создать одинаковую функцию и хранимую процедуру, посмотреть в чем разница в производительности и почему.

    Чтобы не плодить сущности - создание проводим на базе задачи 2
*/
----------------------------------------------------------------------

/* процедура */
CREATE or ALTER Procedure Sales.proc_GetInvoicesByCustomerID @CustomerID int
WITH execute as OWNER
AS
BEGIN
    select SII.CustomerID, SII.InvoiceID, SII.InvoiceDate, sum(sil.Quantity*sil.UnitPrice) as [Сумма покупки на дату]
    from Sales.InvoiceLines sil
    inner join (select  CustomerID, InvoiceID, InvoiceDate from Sales.Invoices si where si.CustomerID = @CustomerID) SII
        on SII.InvoiceID = sil.InvoiceID
    group by SII.CustomerID, SII.InvoiceID, SII.InvoiceDate
END


/* аналогичная функция */

CREATE or ALTER Function Sales.func_GetInvoicesByCustomerID (@CustomerID int)
Returns Table
AS
RETURN (
   select SII.CustomerID, SII.InvoiceID, SII.InvoiceDate, sum(sil.Quantity*sil.UnitPrice) as [Сумма покупки на дату]
    from Sales.InvoiceLines sil
    inner join (select  CustomerID, InvoiceID, InvoiceDate from Sales.Invoices si where si.CustomerID = @CustomerID) SII
        on SII.InvoiceID = sil.InvoiceID
    group by SII.CustomerID, SII.InvoiceID, SII.InvoiceDate
)


SET STATISTICS TIME ON;
exec Sales.proc_GetInvoicesByCustomerID 834;
SET STATISTICS TIME OFF;
/*
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 0 мс, истекшее время = 0 мс.

(затронуто записей: 116)

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 4 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 4 мс.

Время выполнения: 2026-06-08T01:35:21.2931828+03:00
*/
SET STATISTICS TIME ON;
select * from Sales.func_GetInvoicesByCustomerID(834);
SET STATISTICS TIME OFF;
/*

(затронуто записей: 116)

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 15 мс.

Время выполнения: 2026-06-08T01:35:33.0463750+03:00

*/

/*
    Время работы процедуры значительно меньше

    Вероятно это связано с различием исполнения кода.
    Функция пересобирается при каждом запуске, для нее сложно построить оптимальный план выполнения.

*/