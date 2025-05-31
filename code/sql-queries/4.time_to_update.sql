WITH db_status AS (
	SELECT MAX(interval_start) as max_start, MIN(interval_start) as min_start, MAX(interval_end) as max_end, MIN(interval_end) as min_end
	FROM relations_minified
)
SELECT *
FROM db_status;
-- output:
--   db_creation_date   
-- ---------------------
--  2024-08-20 18:41:11
-- (1 row)



CREATE TABLE time_to_update_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM relations_minified
 WHERE is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- rows created: 577531


CREATE TABLE time_total_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS total_time
  FROM relations_minified
 WHERE is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- rows created: 990839



-- find packages having first and last release difference more than 30 days
SELECT *
FROM (
	SELECT system_name, package_name, MAX(release_date) - MIN(release_date) as lifetime, MAX(release_date) AS last_release_date, COUNT(version_name) as num_versions
	FROM versioninfo_extended
	GROUP BY system_name, package_name
) AS x
WHERE EXTRACT(DAY FROM lifetime) > 30 and num_versions > 5;
-- 17 sec



CREATE TABLE time_data_from_to_maintained AS
-- -- we already have the maintained packages in 'selected_packages' table
-- WITH maintained AS (
-- 	SELECT system_name, package_name
-- 	FROM (
-- 		SELECT system_name, package_name, MAX(release_date) - MIN(release_date) as lifetime, MAX(release_date) AS last_release_date, COUNT(version_name) as num_versions
-- 		FROM versioninfo_extended
-- 		GROUP BY system_name, package_name
-- 	) AS x
-- 	WHERE EXTRACT(DAY FROM lifetime) > 730  -- from courtney paper (2+ years of regular maintanance)
-- 		AND last_release_date > '2022-08-17 00:00:00'  -- only packages that had a version release within the last 2 years
-- 		-- AND num_versions > 5  -- probably don't need it anymore
-- )
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM time_total_from_to E
INNER JOIN selected_packages H
ON E.system_name = H.system_name 
	AND E.to_package_name = H.package_name -- restricting to only packages that are maintained as dependencies
INNER JOIN selected_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN time_to_update_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- rows: 990839


CREATE TABLE mean_time_to_update_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM time_data_from_to_maintained
WHERE total_time != 0
GROUP BY system_name,
		 from_package_name;
-- rows: 163207