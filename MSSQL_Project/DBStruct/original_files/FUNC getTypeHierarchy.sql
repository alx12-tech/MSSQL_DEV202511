/*	
    Табличная функция
    Назначение:
        формирование таблицы - списка узлов от искходной точки иерархии
    Входные параметры:
        номер версии справочника
        узловой элемент
    Выходные параметры:
        таблица с полями
            идентификатор записи
            наименование записи
            уровень от исходного узла
            структура подчинённости
    Описание:
        возвращает таблицу с линейным перечнем от заданного узла
    Применяемость:
        для процедур и функций, использующих иерархический справочник
*/
USE PersonalFinance_v4
GO

/************************************************/
CREATE or ALTER function Accounting.getTypeHierarchy (
    @id_version int,
    @start_position_id int
	)
returns @return_table table   (
    id_node  int,
    node_name nvarchar(1024),
    lvl int,
    path_tree nvarchar(max)
    )

WITH exec as OWNER
AS
BEGIN
	with CTE_hierarchy AS--формирование исходной таблицы для обработки
	(
--		declare @id_version int = 1;--тестовая строка
		SELECT
			dth.id_type as id,
			dt.[description] as descr,
			dth.parent_id as parent_id
		FROM Accounting.DIC_TYPE_HIERARCHY dth
		left join Accounting.DIC_TYPE dt on dt.id_type = dth.id_type
--		left join Accounting.DIC_TYPE_HIERARCHY_version dthv on dthv.id_version = dth.id_version
		where	dth.id_version = @id_version		
	),
	hrch_cte as (--первый уровень
		Select 
			id, 
			descr, 
			parent_id,
			1 as LVL,
			cast(@start_position_id as nvarchar(max) ) + N'->' + cast(id as nvarchar(max)) as path_tree
		from CTE_hierarchy
		where Parent_id = @start_position_id
	
		UNION ALL
	
		select--прочие уровни
			h.id,
			h.descr,
			h.Parent_id,
			c.lvl + 1,
			c.path_tree + N'->' + cast(h.id as nvarchar(max))
		from CTE_hierarchy as h
		join hrch_cte as c on h.Parent_id = c.id
	)
	--основной селектор
	insert into @return_table
	select--добавление корневого элемента
		id,
		descr as HierarchyName,
		0 as lvl,
		cast(@start_position_id as nvarchar(max) ) as path_tree
	FROM CTE_hierarchy
	where id = @start_position_id
	
	UNION ALL
	
	select--остальная иерархия
		id,
		replicate(N'  ', lvl) + descr as HierarchyName,
		lvl,
		path_tree
	from hrch_cte
--	order by path_tree

	RETURN
END
GO
--применяемые справочники
/*
select * from Accounting.DIC_TYPE_HIERARCHY
select * from Accounting.DIC_TYPE
select * from Accounting.DIC_TYPE_HIERARCHY_version
*/

--тестирование
--select * from Accounting.getTypeHierarchy(1, 100)