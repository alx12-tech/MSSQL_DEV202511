/*
    Пользовательская процедура
    Назначение: закрытие записи расчёта
    Входные параметры:
        номер расчёта
    Выходные параметры:
        идентификатор если всё ок
        -1 если расчёт уже был закрыт ранее
    Описание:
        закрытие расчёта
    Дополнение:
        вызов из процедуры не являющейся создателем расчёта не считается исключением, т.к. в общем случае сценарий может включать последовательный вызов нескольких процедур
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER procedure Accounting.FINISH_NEW_CALC
    @id_calc int = -1 OUTPUT

WITH execute as OWNER
AS
    declare @current_date datetime2 = getdate()
    --запись должна существовать
    -- расчёт не должен быть закрыт
    if  exists (select 1 from Accounting.DIC_CALC where id_calc = @id_calc)
        AND
        (select date_end from Accounting.DIC_CALC where id_calc = @id_calc) is NULL
        --метка даты закрытия записи
        UPDATE Accounting.dic_calc
        SET date_end = @current_date
        where id_calc = @id_calc
    ELSE
        set @id_calc = -1

GO

/*
---тестирование
--1-й запуск - закрытие записи
--2-й запуск - код -1 на уже закрытую запись
declare @return_code_ int = 2;
exec Accounting.FINISH_NEW_CALC
    @id_calc = @return_code_ output

select @return_code_
select * from Accounting.dic_calc


--несуществующая запись
declare @return_code_ int = 1000;
exec Accounting.FINISH_NEW_CALC
    @id_calc = @return_code_ output

select @return_code_
select * from Accounting.dic_calc
*/