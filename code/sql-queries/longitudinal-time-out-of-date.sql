WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT *
FROM highest;

CREATE TABLE long_time_out_of_date_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT system_name,
		from_package_name,
		to_package_name,
		EXTRACT(YEAR FROM COALESCE(interval_end, (select db_creation_date from highest))) AS year_,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name,
		  interval_end;


CREATE TABLE long_time_total_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT system_name,
		from_package_name,
		to_package_name,
		EXTRACT(YEAR FROM COALESCE(interval_end, (select db_creation_date from highest))) AS year_,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS total_time
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
--   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name,
		  interval_end;
		  
		  
CREATE TABLE long_time_data_from_to AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.year_,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date--,
		--COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM long_time_total_from_to E
LEFT JOIN long_time_out_of_date_from_to F
ON E.system_name = F.system_name AND E.from_package_name = F.from_package_name AND E.to_package_name = F.to_package_name AND E.year_ = F.year_;
-- 15 sec

SELECT current_database();

-- Table Size
SELECT pg_size_pretty(pg_relation_size('long_time_total_from_to'));


CREATE TABLE long_time_out_of_date_conbined AS
SELECT system_name,
		year_,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM long_time_data_from_to
GROUP BY system_name,
		 from_package_name,
		 year_;