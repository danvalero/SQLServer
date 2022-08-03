DECLARE @BigThresholdKB int;
SET @BigThresholdKB = 10485760; --10Gb

WITH Index_Size_CTE 
AS  
-- Define the first CTE query.  
(  
	SELECT
	 OBJECT_SCHEMA_NAME(i.OBJECT_ID) AS SchemaName
	,OBJECT_NAME(i.OBJECT_ID) AS ObjectName
	,i.object_id
	,i.index_id 
	,i.name AS IndexName
	,i.index_id AS IndexID
	,8 * SUM(a.used_pages) AS 'IndexSizeKB'
	FROM sys.indexes AS i
	JOIN sys.partitions AS p ON p.OBJECT_ID = i.OBJECT_ID AND p.index_id = i.index_id
	JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
	GROUP BY i.OBJECT_ID,i.index_id,i.name,i.fill_factor
)  
,
Index_Usage_Detail_CTE 
AS
(
select OBJECT_SCHEMA_NAME(I.object_id) AS SchemaName
	, OBJECT_NAME(I.object_id) AS ObjectName
	, I.name
	, I.object_id
	, I.index_id
	, I.type_desc
	, I.is_unique
	, I.is_primary_key
	, I.is_unique_constraint
	, I.fill_factor
	, I.is_disabled
	, I.is_hypothetical
	, I.has_filter
	, I.filter_definition
   ,STUFF(REPLACE(REPLACE((
        SELECT QUOTENAME(c.name) + CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE '' END AS [data()]
        FROM sys.index_columns AS ic
        INNER JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH
    ), '<row>', ', '), '</row>', ''), 1, 2, '') AS KeyColumns,
    STUFF(REPLACE(REPLACE((
        SELECT QUOTENAME(c.name) AS [data()]
        FROM sys.index_columns AS ic
        INNER JOIN sys.columns AS c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
        ORDER BY ic.index_column_id
        FOR XML PATH
    ), '<row>', ', '), '</row>', ''), 1, 2, '') AS IncludedColumns,
    u.user_seeks,
    u.user_scans,
    u.user_lookups,
    u.user_updates,
	ds.name filegroup
FROM sys.indexes AS I 
LEFT JOIN sys.dm_db_index_usage_stats AS u ON I.object_id = u.object_id AND I.index_id = u.index_id
LEFT JOIN sys.data_spaces AS ds ON ds.data_space_id = I.data_space_id
)
SELECT S.SchemaName, S.ObjectName, S.IndexName, S.object_id, S.index_id, D.filegroup
    , CASE 
		WHEN S.ObjectName IN ( 
							'cargos'
							,'contratos_movimientos_estado'
							,'ordenes_trabajo'
							,'contratos_cargos'
							,'contratos'
							,'historico_detalle_plazos'
							,'pagos_mes'
							,'buro_credito_suscriptores'
							,'temporizador'
							,'mov_ubicaciones_equipo'
							,'totales_colonia'
							,'bitacora_eventos'
							,'paquetes_definicion'
							,'totales_estados'
							,'ventas_semanal'
							,'bitacora_convertidores'
							,'ventas'
							,'contratos_equipos'
							,'promociones_contratos'
							,'inco_log') 
						THEN 1
		ELSE 0
	  end isBig 
	, D.type_desc
	, S.IndexSizeKB 
	, D.fill_factor
	, case when 
		D.fill_factor = 0  then 100
		else D.fill_factor
	  end as fill_factor_real
	, case when 
		(D.fill_factor = 0 OR D.fill_factor = 100)  then 0
		else (S.IndexSizeKB - ((S.IndexSizeKB /100) * D.fill_factor)) 
	  end as EmptySpaceDuetoFillFactorKB
	, D.is_unique
	, D.is_primary_key
	, D.is_unique_constraint
	, D.is_disabled
	, D.is_hypothetical
	, D.has_filter
	, D.filter_definition
	, D.KeyColumns
	, D.IncludedColumns
    , D.user_seeks
    , D.user_scans
    , D.user_lookups
	, D.user_seeks + D.user_scans + D.user_lookups AS user_seeks_lookups_scans
    , D.user_updates
	,'sp_estimate_data_compression_savings ''' + S.SchemaName + ''',''' + S.ObjectName + ''',' + cast (S.index_id as varchar) + ',NULL,ROW' as estimate_compression_row
	,'sp_estimate_data_compression_savings ''' + S.SchemaName + ''',''' + S.ObjectName + ''',' + cast (S.index_id as varchar) + ',NULL,PAGE' as estimate_compression_page
	,'ALTER INDEX [' + S.IndexName + '] ON [' +S.SchemaName + '].[' + S.ObjectName + '] REBUILD WITH (ONLINE=OFF, MAXDOP=1, SORT_IN_TEMPDB = OFF, FILLFACTOR = 85,DATA_COMPRESSION=NONE)' AS rebuild_command_template
FROM Index_Size_CTE S
	left join Index_Usage_Detail_CTE D
		ON S.object_id = D.object_id AND S.index_id = D.index_id
WHERE objectproperty(S.object_id,'IsUserTable') = 1
ORDER BY S.SchemaName, S.ObjectName
