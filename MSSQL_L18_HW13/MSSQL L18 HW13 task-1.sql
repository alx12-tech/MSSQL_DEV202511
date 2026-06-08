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
/*  Задание 1
    Написать функцию возвращающую Клиента с наибольшей суммой покупки.

    В задаче не указаны параметры клиента (CustomerID или CustomerID+CustomerName)
    Результатом будет таблица с параметрами клиента и заказа.
    
    ниже закоментирован вариант скалярной функции для возврата CustomerID (для применения в задании 2)
*/
----------------------------------------------------------------------

CREATE or ALTER Function Sales.CustomerWithMaxInvoice ()
RETURNS Table 
AS
RETURN (
    --запрос формирующий данные
    select sc.CustomerID, sc.CustomerName, CID.InvoiceID, CID.InvoiceDate, CID.InvoiceSum
    from Sales.Customers sc
    inner join 
        (   select si.CustomerID, si.InvoiceID, si.InvoiceDate, IID.InvoiceSum
            from Sales.Invoices si 
            inner join (
                --максимальная покупка
                select top 1
                        InvoiceID,
                        sum(sil.Quantity*UnitPrice) over (partition by InvoiceID) as InvoiceSum
                from Sales.InvoiceLines sil
                order by InvoiceSum desc
            ) IID on IID.InvoiceID = si.InvoiceID
        ) CID on CID.CustomerID = sc.CustomerID
)
GO  
--проверка результата
select * from Sales.CustomerWithMaxInvoice()



/* --скалярный вариант, работает
CREATE or ALTER Function Sales.CustomerIDWithMaxInvoice ()
RETURNS INT
AS
BEGIN
    declare @result int
    --запрос формирующий данные
    set @result = (
        select top 1 sc.CustomerID--ограничение на случай некорректных даннных в таблицах
        from Sales.Customers sc
        inner join 
            (   select si.CustomerID, si.InvoiceID, si.InvoiceDate, IID.InvoiceSum
                from Sales.Invoices si 
                inner join (
                    --максимальная покупка
                    select top 1
                            InvoiceID,
                            sum(sil.Quantity*UnitPrice) over (partition by InvoiceID) as InvoiceSum
                    from Sales.InvoiceLines sil
                    order by InvoiceSum desc
                ) IID on IID.InvoiceID = si.InvoiceID
            ) CID on CID.CustomerID = sc.CustomerID
    )
    Return (@result)
END
GO  
--проверка результата
print(Sales.CustomerIDWithMaxInvoice())

*/