/*
    Пользовательская процедура
    Назначение: создание записи нового расчёта
    Входные параметры:
        наименование процедуры
    Выходные параметры:
        идентификатор
    Описание:
        создаёт запись нового расчёта
        возвращает полученный идентификатор расчёта
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER procedure Accounting.GET_NEW_CALC
    @id_calc int = -1 OUTPUT,
    @proc_name nvarchar(1024),
    @id_scenario int,
    @id_corr int

WITH execute as OWNER
AS
    declare @current_date datetime2 = getdate()

    insert into Accounting.dic_calc 
        (date_start, date_end, id_corr, descr, id_scenario)
    values
        (@current_date, NULL, @id_corr, @proc_name, @id_scenario)
    
    set @id_calc = (
        select top 1 id_calc
        from Accounting.dic_calc
        where 1=1
            AND date_start = @current_date
            AND date_end is NULL
            AND id_corr = @ID_CORR
            AND descr = @proc_name
            AND id_scenario = @id_scenario
        )
--        RETURN @return_code
GO

/*
---тестирование
declare @return_code_ int = 0;
exec Accounting.GET_NEW_CALC
    @id_calc = @return_code_ output,
    @proc_name = 'testing',
    @id_scenario = -1,
    @id_corr = -1

select @return_code_
select * from Accounting.dic_calc
*/