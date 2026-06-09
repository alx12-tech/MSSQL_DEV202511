/*
	Постановка запроса в очередь
*/

CREATE or alter PROCEDURE Sales.ClientInvoiceCountRequest
        @CustomerID INT
    ,   @BeginDate  Date
    ,   @EndDate    Date
AS
BEGIN
	SET NOCOUNT ON;

	--Send to the Target
	DECLARE @InitDlgHandle UNIQUEIDENTIFIER; --!!!
	DECLARE @RequestMessage NVARCHAR(4000);

	BEGIN TRAN --!!!

		SELECT @RequestMessage = (
                        SELECT  CustomerID  as CustomerID,
                                @BeginDate      as BeginDate,
                                @EndDate        as EndDate
                        FROM Sales.Customers as Params
                        WHERE CustomerID = @CustomerID 
                        FOR XML Auto, root('RequestMessage'), elements
                                )
		--Параметры отправки
		BEGIN DIALOG @InitDlgHandle --Указатель на диалог
		FROM SERVICE [//WWI/SLSINV/InitiatorService] TO SERVICE '//WWI/SLSINV/TargetService'
		ON CONTRACT [//WWI/SLSINV/Contract]
		WITH ENCRYPTION = OFF;

		--Отправка сообщения
		SEND ON CONVERSATION @InitDlgHandle MESSAGE TYPE [//WWI/SLSINV/RequestMessage] (@RequestMessage);

SELECT	'DEBUG' as [Mode],
		'ClientInvoiceCountRequest' as [Procedure],
		N'Отправлен запрос:' as [Action],
		@RequestMessage AS [Message];

	COMMIT TRAN
END
GO
