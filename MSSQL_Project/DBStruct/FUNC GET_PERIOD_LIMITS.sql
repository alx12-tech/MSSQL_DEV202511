/*
    табличная функция
    Назначение: возвращает границы расчётного интервала
    Входные параметры:
        идентификатор (строго > 0)
    Выходные параметры:
        код результата (номер периода - ок, -1 ошибка входных параметров)
        левая граница
        правая граница
    при ошибке границы будут возвращены как 1900-01-01
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER FUNCTION Accounting.GET_PERIOD_LIMITS(@id_period int)
returns @return_table table   (
    return_code int,
    left_margin date,
    right_margin date,
    descr nvarchar(1024)
    )
WITH execute as OWNER
    --установка значений по умолчанию (как для ошибки, при успехе будут перезаписаны)
AS
BEGIN
    

    declare 
        @return_code int = -1,
        @left_margin date = datefromparts(1900,1,1),
        @right_margin date = datefromparts(1900,1,1),
        @descr nvarchar(1024) = 'error'
    
    if exists (select 1 from Accounting.dic_period dp where dp.id_period = @id_period)
    select 
        @return_code = @id_period,
        @left_margin = dp.left_margin,
        @right_margin = dp.right_margin,
        @descr = dp.[description]
    from Accounting.dic_period dp where dp.id_period = @id_period

    INSERT INTO @return_table
    select 
        @return_code,
        @left_margin,
        @right_margin,
        @descr
    RETURN;

END
GO
--tests
--is ok
--select * from Accounting.GET_PERIOD_LIMITS(100)
--is not ok
--select * from Accounting.GET_PERIOD_LIMITS(1000)
