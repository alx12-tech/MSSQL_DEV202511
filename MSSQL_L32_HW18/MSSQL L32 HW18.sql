--оригинальный запрос
set statistics time on--статистика

Select  ord.CustomerID, 
            det.StockItemID, 
            SUM(det.UnitPrice), 
            SUM(det.Quantity), 
        COUNT(ord.OrderID)    
FROM Sales.Orders AS ord
    JOIN Sales.OrderLines AS det
        ON det.OrderID = ord.OrderID
    JOIN Sales.Invoices AS Inv 
        ON Inv.OrderID = ord.OrderID
    JOIN Sales.CustomerTransactions AS Trans
        ON Trans.InvoiceID = Inv.InvoiceID
    JOIN Warehouse.StockItemTransactions AS ItemTrans
        ON ItemTrans.StockItemID = det.StockItemID
WHERE Inv.BillToCustomerID != ord.CustomerID
    AND (Select SupplierId
         FROM Warehouse.StockItems AS It
         Where It.StockItemID = det.StockItemID) = 12
    AND (SELECT SUM(Total.UnitPrice*Total.Quantity)
        FROM Sales.OrderLines AS Total
            Join Sales.Orders AS ordTotal
                On ordTotal.OrderID = Total.OrderID
        WHERE ordTotal.CustomerID = Inv.CustomerID) > 250000
    AND DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0
GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID

--Анализ скрипта
Select  ord.CustomerID,     --использует таблицу Orders
        det.StockItemID,    --использует таблицу OrderLines
        SUM(det.UnitPrice), --использует таблицу OrderLines
        SUM(det.Quantity),  --использует таблицу OrderLines
        COUNT(ord.OrderID)  --использует таблицу Orders
FROM Sales.Orders AS ord --применяется как базовая таблица запроса
    JOIN Sales.OrderLines AS det ON det.OrderID = ord.OrderID--детализация таблицы, желательно использовать как основной
    JOIN Sales.Invoices AS Inv ON Inv.OrderID = ord.OrderID--используется для расширения количества полей, фильтрация
    JOIN Sales.CustomerTransactions AS Trans ON Trans.InvoiceID = Inv.InvoiceID--для расширения аналитик, фильтрация
    JOIN Warehouse.StockItemTransactions AS ItemTrans ON ItemTrans.StockItemID = det.StockItemID--расширение аналитик
WHERE Inv.BillToCustomerID != ord.CustomerID--фильтрация по различию
--коррелированный подзапрос с фильтром, перенести в JOIN
    AND (Select SupplierId FROM Warehouse.StockItems AS It Where It.StockItemID = det.StockItemID) = 12
--ещё коррелированный подзапрос с фильтром - в CTE (или времянку) и JOIN
    AND (   SELECT SUM(Total.UnitPrice*Total.Quantity) 
            FROM Sales.OrderLines AS Total
                    Join Sales.Orders AS ordTotal 
                    On ordTotal.OrderID = Total.OrderID
            WHERE ordTotal.CustomerID = Inv.CustomerID
        ) > 250000
--применение функции в WHERE не оптимально - перенести в условие JOIN
    AND DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0
GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID
/*
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 0 мс, истекшее время = 0 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 0 мс.
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 94 мс, истекшее время = 130 мс.

(затронуто записей: 3619)

(затронута 1 запись)

 Время работы SQL Server:
   Время ЦП = 500 мс, затраченное время = 1153 мс.
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 0 мс, истекшее время = 0 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 0 мс.
*/

-------------------------------------------------------
--Анализ скрипта
;with CTE as (
    SELECT ordTotal.CustomerID, SUM(Total.UnitPrice*Total.Quantity) as SUMM
    FROM Sales.OrderLines AS Total--попозиционная сумма товара в заказе
        Join Sales.Orders AS ordTotal On ordTotal.OrderID = Total.OrderID--для заказчика = плательщику
    group by ordTotal.CustomerID
    having SUM(Total.UnitPrice*Total.Quantity) > 250000
)

Select  ord.CustomerID, --Orders
        det.StockItemID, --OrderLines
        SUM(det.UnitPrice), --OrderLines
        SUM(det.Quantity), --OrderLines
        COUNT(ord.OrderID)    --Orders
FROM Sales.OrderLines AS det 
    join Warehouse.StockItems AS It on It.StockItemID = det.StockItemID and it.SupplierId=12 --ограничение на основную таблицу
    JOIN Warehouse.StockItemTransactions AS ItemTrans ON ItemTrans.StockItemID = det.StockItemID--ограничение на основную таблицу
    JOIN Sales.Orders AS ord ON det.OrderID = ord.OrderID--расширение полей данных
    JOIN Sales.Invoices AS Inv --доп.условие из блока WHERE
        ON      Inv.OrderID = ord.OrderID 
            and Inv.BillToCustomerID != ord.CustomerID 
            and DATEDIFF(dd, Inv.InvoiceDate, ord.OrderDate) = 0
    join CTE as c on c.CustomerID = INV.CustomerID--вместо коррелированного подзапроса в WHERE
    JOIN Sales.CustomerTransactions AS Trans ON Trans.InvoiceID = Inv.InvoiceID
GROUP BY ord.CustomerID, det.StockItemID
ORDER BY ord.CustomerID, det.StockItemID

/*
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 0 мс, истекшее время = 0 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 0 мс.
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 150 мс, истекшее время = 150 мс.

(затронуто записей: 3619)

(затронута 1 запись)

 Время работы SQL Server:
   Время ЦП = 453 мс, затраченное время = 701 мс.
Время синтаксического анализа и компиляции SQL Server: 
 время ЦП = 0 мс, истекшее время = 0 мс.

 Время работы SQL Server:
   Время ЦП = 0 мс, затраченное время = 0 мс.
*/

-----------------------------


