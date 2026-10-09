/*
    Пользовательская процедура
    Назначение: выгрузка проовдок за текущий период в формате для загрузки.
        Для последующего дополнения и загрузки обратно.
    Входные параметры:
        идентификатор периода
    Выходные параметры:
        таблица установленного формата
    Описание:
        реализован базовый функционал
        в плане 
            - явное задание периода, сейчас используется только дефолтный - текущий
            - оптимизация (предварительно через времянки для fct_Carry - таблица будет расти - кандидат на секционирование)

  */
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER FUNCTION STAGE.FCT_CARRY_DOWNLOAD_FORMAT (@id_period int)
returns 
    @return_table table   (
           [CARRY_DATE] datetime2
          ,[TURNOVER_SUM] numeric(28,12)
          ,[account_name] nvarchar(1024)
          ,[client_name] nvarchar(1024)
          ,[agreement_name] nvarchar(1024)
          ,[carry_ground] nvarchar(1024)
          ,[bal2] nvarchar(512)
          ,[extra_data] nvarchar(1024)
    )
WITH execute as OWNER
AS
BEGIN
    --выборка опознание пределов из get_period_limits
    declare @left_margin date, @right_margin date
    --получение границ периода
    select
        @left_margin = a.left_margin,
        @right_margin = a.right_margin
    from accounting.get_period_limits(@id_period) a

    INSERT INTO @return_table
        SELECT 
            fc.[CARRY_DATE]
            ,fc.VL as [TURNOVER_SUM]--при доработке, сумма по группе
            ,da.[account_name]
            ,dc.[client_name]
            ,dag.[agreement_name]
            ,fc.[carry_ground]
            ,db2.[name] as bal2 --под доработку - добавить версионирование (технически в 99% случаев между планами наименования не повторяются, но...)
            ,' ' as [extra_data] -- поле на перспективу, в будущем туда (и оттуда) будут собираться доп.атрибуты
        --select * 
        FROM Accounting.FCT_CARRY fc--таблица пустая, надо что-то положить туда
        left join Accounting.dic_account da on da.id_account = fc.id_account
        left join Accounting.DIC_BAL2 db2 on db2.id_bal2 = da.id_bal2
        left join Accounting.dic_client dc on dc.id_client = da.id_client
        left join Accounting.dic_agreement  dag on dag.id_agreement = fc.id_agreement
        where fc.carry_date between @left_margin and @right_margin
    RETURN;

END



/*

-- тестирование

--select * from accounting.get_period_limits(106)
--select * from accounting.dic_period
select * from STAGE.FCT_CARRY_DOWNLOAD_FORMAT(106)


  
*/