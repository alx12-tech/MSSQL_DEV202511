/*
    Пользовательская процедура
    Назначение: создание записи нового расчётного периода
    Входные параметры:
        идентификатор
        Описание - краткое текстовое описание
        левая граница
        правая граница
    Выходные параметры:
        идентификатор (>0) если запись создана
        -1 если создание записи не удалось
    Описание:
        реализован базовый функционал
        процедура проверяет наличие идентификатора, границы
            если запись отсутствует - создаёт
            если есть идентификатор, либо существуют границы - возвращает ошибку
    Доп.инфо:
        номера идентификаторов не присваиваются автоматически, т.к.:
            в плане - разделение номеров по назначению
            исключить многократное создание од
        доп. ограничения - проверяется инкремент (номера могут быть только возрастающими)
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER procedure Accounting.CREATE_NEW_PERIOD
    @ID_PERIOD int = -1 OUTPUT,
    @DESCR varchar(512),
    @Left_margin date,
    @right_margin date

WITH execute as OWNER
AS
    
    declare @return_code int = -1
    --вставка выполняется только если 
        --отсутствует номер периода (при любых границах)
        --отсутствует сочетание границ (при любом номере)
        --задано корректное сочетание (левая левее правой)
    if (
        not exists (
                    select 1 from Accounting.dic_period dp 
                    where dp.id_period = @id_period
                    )
        AND
        not exists (select 1 from Accounting.dic_period dp 
                    where dp.id_period = @id_period
                    )
        AND
        @Left_margin < @right_margin
        )
        BEGIN
            print 'секция обработки'
            insert into Accounting.dic_period 
            (id_period, left_margin, right_margin, [description] )
            values 
            (@ID_PERIOD, @Left_margin, @right_margin, @DESCR);
        END
    ELSE
        BEGIN
            print 'Секция ошибки'
            select @ID_PERIOD = @return_code
        END

GO

/*
-- тестирование
--тест корректный
declare   
    @PERIOD int = -1100,--тестовое значение
    @DESCR varchar(512) = 'тест',
    @Left_margin date = '2020-01-01',
    @right_margin date = '2021-01-01'

exec Accounting.CREATE_NEW_PERIOD
      @ID_PERIOD = @period OUTPUT,
      @DESCR = @descr,
      @Left_margin = @left_margin,
      @right_margin = @right_margin
      ;

select @period as return_code

select * from Accounting.dic_period dp where dp.id_period = -1100


--тест не корректные границы
declare   
    @PERIOD int = -1001,--тестовое значение
    @DESCR varchar(512) = 'тест',
    @Left_margin date = '2020-01-01',
    @right_margin date = '2019-01-01'

exec Accounting.CREATE_NEW_PERIOD
      @ID_PERIOD = @period OUTPUT,
      @DESCR = @descr,
      @Left_margin = @left_margin,
      @right_margin = @right_margin
      ;

select @period as return_code
select * from Accounting.dic_period dp where dp.id_period = -1001


--тест существующий идентификатор
declare   
    @PERIOD int = -1001,--тестовое значение
    @DESCR varchar(512) = 'тест',
    @Left_margin date = '2020-01-01',
    @right_margin date = '2020-01-01'

exec Accounting.CREATE_NEW_PERIOD
      @ID_PERIOD = @period OUTPUT,
      @DESCR = @descr,
      @Left_margin = @left_margin,
      @right_margin = @right_margin
      ;

select @period as return_code
select * from Accounting.dic_period dp where dp.id_period = -1001
    
*/