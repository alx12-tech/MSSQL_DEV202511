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
/*  Задание 4
    Создайте табличную функцию покажите как ее можно вызвать для каждой строки result set'а без использования цикла.
*/
----------------------------------------------------------------------

/*
    для примера возьмём функцию из примера 3
    код приведён для наглядности, функция была создана ранее

*/

/*
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
*/

--пример вызова

select i.CustomerID as CustomerID_original,
       func.*
from (select top 10 CustomerID from Sales.Customers) i
OUTER APPLY Sales.func_GetInvoicesByCustomerID(i.CustomerID) as func
