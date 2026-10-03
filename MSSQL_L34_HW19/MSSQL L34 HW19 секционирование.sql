--Секционирование выполняется для существующей таблицы Accounting.FCT_CARRY
--ожидаемый объем строк в таблице на горизонте 2-3 года не превышает 1 млн строк
--т.е. дополнительных мер по поддержке процесса перестроения индкеса пока не требуется


USE PersonalFinance_v4
GO

--системное имя ограничения для дальнейшего использования
SELECT name 
FROM sys.key_constraints 
WHERE parent_object_id = OBJECT_ID('Accounting.FCT_CARRY') AND type = 'PK';

--результат: PK__FCT_CARR__150B5C787101A808

-- СОЗДАНИЕ ФУНКЦИИ И СХЕМЫ СЕКЦИОНИРОВАНИЯ
-- 01.01.2025 уходит в секцию 2025 года
CREATE PARTITION FUNCTION pf_CarryDate_Yearly (datetime2)
AS RANGE RIGHT FOR VALUES 
(
    '2024-01-01 00:00:00',
    '2025-01-01 00:00:00',
    '2026-01-01 00:00:00',
    '2027-01-01 00:00:00',
    '2028-01-01 00:00:00'
);
GO


-- Создаем схему секционирования (для MVP все секции сажаем на файловую группу PRIMARY)
CREATE PARTITION SCHEME ps_CarryDate_Yearly
AS PARTITION pf_CarryDate_Yearly
ALL TO ([PRIMARY]);
GO

-- 2. МОДИФИКАЦИЯ ПЕРВИЧНОГО КЛЮЧА И СЕКЦИОНИРОВАНИЕ ТАБЛИЦЫ

-- Удаляем существующие внешние ключи, если они ссылаются на FCT_CARRY (если есть)
-- В текущей структуре FCT_CARRY сама ссылается на другие таблицы, поэтому её PK можно удалять сразу.

-- Удаляем старый кластеризованный первичный ключ
ALTER TABLE Accounting.FCT_CARRY 
DROP CONSTRAINT PK__FCT_CARR__150B5C787101A808;
GO

-- Создаем НОВЫЙ кластеризованный первичный ключ, выровненный по схеме секционирования
-- В уникальный кластеризованный индекс ОБЯЗАТЕЛЬНО должно входить поле секционирования (carry_date)
ALTER TABLE Accounting.FCT_CARRY
ADD CONSTRAINT PK_Accounting_FCT_CARRY_Partitioned 
PRIMARY KEY CLUSTERED (id_CARRY, carry_date)
ON ps_CarryDate_Yearly(carry_date); 
GO

-- ПРОВЕРКА РАСПРЕДЕЛЕНИЯ ДАННЫХ ПО СЕКЦИЯМ
SELECT 
    p.partition_number AS [Номер Секции],
    fg.name AS [Файловая Группа],
    p.rows AS [Количество строк в секции],
    CAST(rv.value AS DATETIME2) AS [Правая граница секции (>=)]
FROM sys.partitions p
INNER JOIN sys.indexes i ON p.object_id = i.object_id AND p.index_id = i.index_id
INNER JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id
LEFT JOIN sys.partition_schemes ps ON ds.data_space_id = ps.data_space_id
LEFT JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
LEFT JOIN sys.partition_range_values rv ON pf.function_id = rv.function_id AND p.partition_number = rv.boundary_id + 1
LEFT JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.data_space_id AND p.partition_number = dds.destination_id
LEFT JOIN sys.filegroups fg ON COALESCE(dds.data_space_id, ds.data_space_id) = fg.data_space_id
WHERE p.object_id = OBJECT_ID('Accounting.FCT_CARRY')
  AND i.index_id = 1; -- Кластеризованный индекс
GO
