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
/*  Задание 2
    Написать хранимую процедуру с входящим параметром СustomerID, выводящую сумму покупки по этому клиенту.
    Использовать таблицы :
    Sales.Customers
    Sales.Invoices
    Sales.InvoiceLines

    Т.к. задача не конкретизирует понятие покупки (одна, кумулятивно по дате, или конкретная покупка), 
    то результатом функции будет таблица.

    для разнообразия, если задано ненатуральное число -
    процедура возьмёт клиента с макисмальной покупкой (функция 1-го задания)
 */
----------------------------------------------------------------------

CREATE or ALTER Procedure Sales.GetInvoicesSumsByCustomerID @CustomerID int
WITH execute as OWNER
AS
BEGIN
--   declare @CustomerID int = -984--тест
    Declare @TestCustomerID int     
    IF @CustomerID <= 0 set @TestCustomerID = Sales.CustomerIDWithMaxInvoice()
    ELSE set @TestCustomerID = @CustomerID

    select SII.CustomerID, SII.InvoiceID, SII.InvoiceDate, sum(sil.Quantity*sil.UnitPrice) as [Сумма покупки на дату]
    from Sales.InvoiceLines sil
    inner join (select  CustomerID, InvoiceID, InvoiceDate from Sales.Invoices si where si.CustomerID = @TestCustomerID) SII
        on SII.InvoiceID = sil.InvoiceID
    group by SII.CustomerID, SII.InvoiceID, SII.InvoiceDate
    ORDER BY SII.InvoiceDate DESC
END

--проверка
exec GetInvoicesSumsByCustomerID 888;
exec GetInvoicesSumsByCustomerID -123;