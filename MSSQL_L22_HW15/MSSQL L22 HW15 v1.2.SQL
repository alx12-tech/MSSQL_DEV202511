/*
Вебинар 22 Очереди
ДЗ 14

Т.к. в проекте объективно очереди не нужны (на этапе MVP точно не нужны), то к выполнению типовое ДЗ.

Реализуйте очередь для БД WideWorldImporters:
1. Создайте очередь для формирования отчетов для клиентов по таблице Invoices. При вызове процедуры для создания отчета в очередь должна отправляться заявка.
2. При обработке очереди создавайте отчет по количеству заказов (Orders) по клиенту за заданный период времени и складывайте готовый отчет в новую таблицу.
3. Проверьте, что вы корректно открываете и закрываете диалоги и у нас они не копятся.
*/

/*	План:

Создать очередь.
Процедуры на стороне инициатора:
    Процедура создания отчёта - открывает диалог, направляет заявку в очередь.
    Процедура проверки отчёта - получает результат выполнения (ошибку или номер отчёта), закрывает диалог.
Процедура-обработчик:
    Получает левую+правую границы временного интервала
    генерит отчёт, кладёт INSERT в таблицу (номер отчёта, номер клиента, интервал, поля отчёта_
    отправляет сообщение с номером отчёта и текстом что всё нагенерили
    случае закрывает диалог

    Демозапуск, результаты... текстом? графикой отчёты?
    Пара запросов с проверкой что дилоги закрыты
*/

--------------------------
--Активацния брокера
USE master
ALTER DATABASE WideWorldImporters SET ENABLE_BROKER  WITH ROLLBACK IMMEDIATE;
--переключение БД
USE WideWorldImporters
GO
---------------
--созданине целевой таблицы
DROP TABLE if exists Sales.ClientReports
Create table Sales.ClientReports (
        ReportID int not NULL IDENTITY(1,1) primary KEY--UNIQUEIDENTIFIER
    ,   CustomerID int not NULL
    ,   BeginDate    date not null
    ,   EndDate      date not null
    ,   Counter     int not null default 0
    )

--тест таблицы
insert into Sales.ClientReports
values
(2,  '2026-05-01', '2026-05-02', 1);
select * from Sales.ClientReports
---------------




--Переключение пользователя на "имеющего право"
ALTER AUTHORIZATION ON DATABASE::WideWorldImporters TO [sa];
GO
--Создание типов сообщений
CREATE MESSAGE TYPE [//WWI/SLSINV/RequestMessage] VALIDATION=WELL_FORMED_XML;
CREATE MESSAGE TYPE [//WWI/SLSINV/ReplyMessage] VALIDATION=WELL_FORMED_XML;
GO
--Создание контракта
CREATE CONTRACT [//WWI/SLSINV/Contract] (
        [//WWI/SLSINV/RequestMessage]   SENT BY INITIATOR
    ,   [//WWI/SLSINV/ReplyMessage]     SENT BY TARGET
    );
GO


--Создание очереди исполнителя
CREATE QUEUE TargetQueueWWI;
CREATE SERVICE [//WWI/SLSINV/TargetService]
    ON QUEUE TargetQueueWWI ([//WWI/SLSINV/Contract]);

--привязка процедуры
ALTER QUEUE TargetQueueWWI
WITH ACTIVATION (
	STATUS = ON -- вкл
	, PROCEDURE_NAME = Sales.ClientInvoiceCountProcess
	, MAX_QUEUE_READERS = 1 --количество обработчиков
	, EXECUTE AS OWNER --
	);
GO

--создание очереди инициатора
CREATE QUEUE InitiatorQueueWWI;
CREATE SERVICE [//WWI/SLSINV/InitiatorService]
    ON QUEUE InitiatorQueueWWI ([//WWI/SLSINV/Contract]);

--привязка процедуры
ALTER QUEUE InitiatorQueueWWI
WITH ACTIVATION (
	STATUS = ON --  вкл
	, PROCEDURE_NAME = Sales.ClientInvoiceCountControl
	, MAX_QUEUE_READERS = 1 --количество обработчиков
    ,EXECUTE as Owner
	);
GO



--Создание хранимых процедур - в отдельных файлах сценариев
/*
CREATE or alter PROCEDURE Sales.ClientInvoiceCountRequest
        @CustomerID INT
    ,   @BeginDate  Date
    ,   @EndDate    Date
CREATE or alter PROCEDURE Sales.ClientInvoiceCountProcess

CREATE or alter PROCEDURE Sales.ClientInvoiceCountControl
*/

--проверки
select * from Sales.ClientReports

select distinct CustomerID from Sales.Invoices where CustomerID > 123

--параметры вызова
declare @CustomerID int = 124
declare @BeginDate  date = '2013-01-07'
declare @EndDate    date = '2016-05-26'
/*--проверка что такое существует
SELECT
    si.CustomerID as CustomerID,
    min(si.InvoiceDate) as BeginDate,
    max(si.InvoiceDate) as EndDate,
    count(*) as Counter
from Sales.Invoices si
    where si.CustomerID = @CustomerID 
    --and (si.InvoiceDate between @BeginDate and @EndDate)
group by CustomerID
*/
exec Sales.ClientInvoiceCountRequest
        @CustomerID = @CustomerID
    ,   @BeginDate  = @BeginDate
    ,   @EndDate    = @EndDate
    ;

exec Sales.ClientInvoiceCountProcess

---контроль
select * from SAles.ClientReports--таблица должна заполняться

--здесь будет добавляться по 2 строки
Select * from SYS.transmission_queue
select * from sys.conversation_endpoints
/* примерно такого вида
conversation_handle	conversation_id	is_initiator	service_contract_id	conversation_group_id	service_id	lifetime	state	state_desc	far_service	far_broker_instance	principal_id	far_principal_id	outbound_session_key_identifier	inbound_session_key_identifier	security_timestamp	dialog_timer	send_sequence	last_send_tran_id	end_dialog_sequence	receive_sequence	receive_sequence_frag	system_sequence	first_out_of_order_sequence	last_out_of_order_sequence	last_out_of_order_frag	is_system	priority
93CFEEA6-3E64-F111-AB2D-080027B0CB2B	D1ACA99F-DF5E-4A60-9668-1A5B76ECDCAA	0	65536	00000000-0000-0000-0000-000000000000	65536	2094-06-27 23:20:15.660	CD	CLOSED	//WWI/SLSINV/InitiatorService	A4BC4230-0390-4025-8AA8-170CE13302D7	1	1	00000000-0000-0000-0000-000000000000	00000000-0000-0000-0000-000000000000	2026-06-09 20:36:39.660	1900-01-01 00:00:00.000	2	0x564979000000	2	1	0	0	-1	0	0	0	5
0A1988BD-3E64-F111-AB2D-080027B0CB2B	9B08ED38-39C8-43F3-B68F-3CB95224D368	0	65536	00000000-0000-0000-0000-000000000000	65536	2094-06-27 23:20:53.573	CD	CLOSED	//WWI/SLSINV/InitiatorService	A4BC4230-0390-4025-8AA8-170CE13302D7	1	1	00000000-0000-0000-0000-000000000000	00000000-0000-0000-0000-000000000000	2026-06-09 20:37:17.573	1900-01-01 00:00:00.000	2	0x5C4979000000	2	1	0	0	-1	0	0	0	5
*/


