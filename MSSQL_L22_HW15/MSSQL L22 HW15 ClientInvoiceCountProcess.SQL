/*
	Обработчик на стороне исполнителя
*/
CREATE or alter PROCEDURE Sales.ClientInvoiceCountProcess
AS
BEGIN

	DECLARE @TargetDlgHandle UNIQUEIDENTIFIER,
			@Message NVARCHAR(4000),
			@MessageType Sysname,
			@ReplyMessage NVARCHAR(4000),
			@ReplyMessageName Sysname,
			@CustomerID INT,
			@BeginDate date,
			@EndDate date,
			@xml XML;

	BEGIN TRAN;

		RECEIVE TOP(1) --!!
			@TargetDlgHandle = Conversation_Handle,
			@Message = Message_Body,
			@MessageType = Message_Type_Name
		FROM dbo.TargetQueueWWI;

SELECT	'DEBUG' as [Mode],
		'ClientInvoiceCountProcess' as [Procedure],
		'MSG recieved:' as [Action],
		@Message as [Message]

		SET @xml = CAST(@Message AS XML);

		-- Извлечение параметров
		SELECT
		    @CustomerID = X.Lv.value('CustomerID[1]','INT') ,
		    @BeginDate = X.Lv.value('BeginDate[1]', 'date'),
		    @EndDate = X.Lv.value('EndDate[1]', 'date')
		FROM @XML.nodes('/RequestMessage/Params') as X(Lv);

        --полезные действия по сообщению
        insert into Sales.ClientReports
        SELECT
            si.CustomerID as CustomerID,
            @BeginDate as BeginDate,
            @EndDate as EndDate,
            count(*) as Counter
        from Sales.Invoices si
            where si.CustomerID = @CustomerID and (si.InvoiceDate between @BeginDate and @EndDate)
        group by CustomerID

		-- ответ
        declare @ReportID int
        set @ReportID = ( select max(ReportID) from Sales.ClientReports);
		IF @MessageType = N'//WWI/SLSINV/RequestMessage' 
		BEGIN
			SET @ReplyMessage = concat(N'<ReportID>', @ReportID, '</ReportID>');
			SEND ON CONVERSATION @TargetDlgHandle MESSAGE TYPE [//WWI/SLSINV/ReplyMessage] (@ReplyMessage);
			END CONVERSATION @TargetDlgHandle; --!!!
		END
		--контроль
SELECT	'DEBUG' as [Mode],
		'ClientInvoiceCountProcess' as [Procedure],
		N'Отправлен ответ:' as [Action],
		@ReplyMessage AS [Message];

	COMMIT TRAN;
END