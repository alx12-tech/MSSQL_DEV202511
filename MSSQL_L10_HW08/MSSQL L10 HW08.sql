/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "10 - Операторы изменения данных".

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

USE WideWorldImporters;

/*
1. Довставлять в базу пять записей используя insert в таблицу Customers или Suppliers 
*/

--проверка текущего количества строк
select count(*) as [Строк в Sales.Customers] from Sales.Customers
/*
Строк в Sales.Customers
663

*/
--времянка для вставки (чтобы не перписывать все поля таблицы)
drop table if exists #temp_table4insert;
select top 5 * into #temp_table4insert from Sales.Customers sc order by sc.CustomerID;
--дописываем маркеры чтобы отличать вставленные строки
update src set src.CustomerName = concat('Test customer name', ' ', cast(src.CustomerID as varchar(16))) from #temp_table4insert src
--проверка результата
select * from #temp_table4insert;
--выкидываем автозаполняемые стоблцы
alter table #temp_table4insert drop column CustomerID, ValidFrom, ValidTo;

--вставка новых строк
insert into Sales.Customers (	--CustomerID--автоинкремент
								 CustomerName
								,BillToCustomerID
								,CustomerCategoryID
								,BuyingGroupID
								,PrimaryContactPersonID
								,AlternateContactPersonID
								,DeliveryMethodID
								,DeliveryCityID
								,PostalCityID
								,CreditLimit
								,AccountOpenedDate
								,StandardDiscountPercentage
								,IsStatementSent
								,IsOnCreditHold
								,PaymentDays
								,PhoneNumber
								,FaxNumber
								,DeliveryRun
								,RunPosition
								,WebsiteURL
								,DeliveryAddressLine1
								,DeliveryAddressLine2
								,DeliveryPostalCode
								,DeliveryLocation
								,PostalAddressLine1
								,PostalAddressLine2
								,PostalPostalCode
								,LastEditedBy
								--,ValidFrom--автозаполнение
								--,ValidTo	--автозаполнение
							)
select * from #temp_table4insert


--проверка полученного количества строк
select count(*) as [Строк в Sales.Customers] from Sales.Customers
/*
Строк в Sales.Customers
668
*/

--вывод вставленных строк по признаку
select * 
from Sales.Customers sc
where sc.CustomerName like 'Test%'



/*
2. Удалите одну запись из Customers, которая была вами добавлена
*/

select * 
from Sales.Customers sc
where sc.CustomerName like 'Test%'
--удаление
delete from Sales.Customers
where CustomerName like 'Test%1'
--демо результата
select * 
from Sales.Customers sc
where sc.CustomerName like 'Test%'

/*
3. Изменить одну запись, из добавленных через UPDATE
*/


--демо AS IS
select * 
from Sales.Customers sc
where sc.CustomerName like 'Test%'
--обновление
update src set src.CustomerName = concat(src.CustomerName, '+', cast(src.CustomerID as varchar(16))) 
from Sales.Customers src
where src.CustomerName like 'Test%3%'--с таким шаблоном строка будет обновляться при каждом запуске
--демо результата
select * 
from Sales.Customers sc
where sc.CustomerName like 'Test%'


/*
4. Написать MERGE, который вставит вставит запись в клиенты, если ее там нет, и изменит если она уже есть
*/

--времянка для вставки (чтобы не перписывать все поля таблицы)
drop table if exists #temp_table4insert;
select * 
into #temp_table4insert 
from Sales.Customers sc 
where sc.CustomerName like 'Test%'
--дописываем маркеры чтобы отличать вставленные строки
update src 
set src.CustomerName = 'Test MERGED record'
from #temp_table4insert src
where src.CustomerName like 'Test%3'
--проверка результата
select * from #temp_table4insert;
--выкидываем автозаполняемые стоблцы
alter table #temp_table4insert drop column CustomerID, ValidFrom, ValidTo;

--demo 
select count(*) from Sales.Customers--
--
select *  
from Sales.Customers sc
where sc.CustomerName like 'Test%'
--action

MERGE Sales.Customers as TGT
USING #temp_table4insert as SRC
	on tgt.CustomerName = src.CustomerName
when MATCHED --совпадение по наименованию
	then UPDATE set CustomerName = src.CustomerName
when NOT MATCHED by target--новые по отношению к целевой
	then INSERT (
					 CustomerName
					,BillToCustomerID
					,CustomerCategoryID
					,BuyingGroupID
					,PrimaryContactPersonID
					,AlternateContactPersonID
					,DeliveryMethodID
					,DeliveryCityID
					,PostalCityID
					,CreditLimit
					,AccountOpenedDate
					,StandardDiscountPercentage
					,IsStatementSent
					,IsOnCreditHold
					,PaymentDays
					,PhoneNumber
					,FaxNumber
					,DeliveryRun
					,RunPosition
					,WebsiteURL
					,DeliveryAddressLine1
					,DeliveryAddressLine2
					,DeliveryPostalCode
					,DeliveryLocation
					,PostalAddressLine1
					,PostalAddressLine2
					,PostalPostalCode
					,LastEditedBy
				)
		values (
					 src.CustomerName
					,src.BillToCustomerID
					,src.CustomerCategoryID
					,src.BuyingGroupID
					,src.PrimaryContactPersonID
					,src.AlternateContactPersonID
					,src.DeliveryMethodID
					,src.DeliveryCityID
					,src.PostalCityID
					,src.CreditLimit
					,src.AccountOpenedDate
					,src.StandardDiscountPercentage
					,src.IsStatementSent
					,src.IsOnCreditHold
					,src.PaymentDays
					,src.PhoneNumber
					,src.FaxNumber
					,src.DeliveryRun
					,src.RunPosition
					,src.WebsiteURL
					,src.DeliveryAddressLine1
					,src.DeliveryAddressLine2
					,src.DeliveryPostalCode
					,src.DeliveryLocation
					,src.PostalAddressLine1
					,src.PostalAddressLine2
					,src.PostalPostalCode
					,src.LastEditedBy
				)
output $action, deleted.*, inserted.*
;

--demo 
select count(*) from Sales.Customers--
--
select *  
from Sales.Customers sc
where sc.CustomerName like 'Test%'

/*
5. Напишите запрос, который выгрузит данные через bcp out и загрузить через bulk insert
*/

EXEC sp_configure 'show advanced options', 1;
--
RECONFIGURE; 
GO
EXEC sp_configure 'xp_cmdshell', 1;
GO
RECONFIGURE; 
GO
--select @@servername

--exec master..xp_cmdshell 'bcp "WideWorldImporters.Sales.Customers" out "C:\Temp\bcp_testout1.txt" -T -w -t$%#@~ -SDESKTOP-LLKHR8E\SQLS22'
DECLARE @command2exec varchar(4096);
set @command2exec = concat(
	'bcp '--command
	,' "WideWorldImporters.Sales.Customers" '--database/table
	,' out'--option key
	,' "C:\Temp\bcp_testout1.txt"' --filename
	,' -T -w -t$%#@~'--options
	,' -S'--servername option
	,@@servername--servername value
	);
print @command2exec;
exec master..xp_cmdshell @command2exec;

/*ВЫВОД:
output
NULL
Начато копирование...
SQLState = S1000, NativeError = 0
Error = [Microsoft][ODBC Driver 17 for SQL Server]Внимание! Импорт BCP с файлом форматирования преобразует пустые строки в столбцах, ограниченных разделителями, придав им значение NULL.
NULL
Скопировано строк: 668.
Размер сетевого пакета (в байтах): 4096
Время (мс) Всего     : 16     В среднем : (41750.00 строк в секунду.)
NULL
*/

--Восстановление структуры таблицы
drop table if exists #CustomersRecovered;
--
select top 0 * 
into #CustomersRecovered
from Sales.Customers
--
select * from #CustomersRecovered
--
BULK INSERT #CustomersRecovered
from "C:\Temp\bcp_testout1.txt"
WITH (--parameters
	batchsize = 1000,
	DataFileType = 'widechar',
	FieldTerminator = '$%#@~',
	RowTerminator = '\n',
	KEEPNULLS,
	TABLOCK
	);

select * from #CustomersRecovered
	