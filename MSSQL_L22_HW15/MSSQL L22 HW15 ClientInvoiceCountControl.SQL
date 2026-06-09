--обработчик ответа на стороне приёмника
CREATE or alter PROCEDURE Sales.ClientInvoiceCountControl
AS
BEGIN
	--Receiving Reply Message from the Target.
	DECLARE @InitiatorReplyDlgHandle UNIQUEIDENTIFIER,
			@ReplyReceivedMessage NVARCHAR(1000)

	BEGIN TRAN;

		RECEIVE TOP(1) -- !!
			@InitiatorReplyDlgHandle=Conversation_Handle
			,@ReplyReceivedMessage=Message_Body
		FROM dbo.InitiatorQueueWWI;

		END CONVERSATION @InitiatorReplyDlgHandle; --!!!

	SELECT	'DEBUG' as [Mode],
		'ClientInvoiceCountControl' as [Procedure],
		N'Результат выполнения:' as [Action],
		@ReplyReceivedMessage AS [Message];

	COMMIT TRAN;
END