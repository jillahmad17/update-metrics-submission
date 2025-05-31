CREATE TABLE time_to_remediate_from_to AS
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
    AND is_exposed = true
    AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- rows: 35729


CREATE TABLE remediate_data_from_to_maintained AS
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
		COALESCE(F.time_out_of_date, 0) AS time_to_remediate,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage_ttr
FROM time_total_from_to E
INNER JOIN selected_packages H
ON E.system_name = H.system_name 
	AND E.to_package_name = H.package_name -- restricting to only packages that are maintained as dependencies
INNER JOIN selected_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN time_to_remediate_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- rows: 990839


CREATE TABLE mean_time_to_remediate_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_to_remediate) AS total_post_fix_exposure_time,
		(SUM(time_to_remediate) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_to_remediate) AS avg_post_fix_exposure_time,
		(AVG(time_to_remediate) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM remediate_data_from_to_maintained
WHERE total_time != 0 AND time_to_remediate != 0
GROUP BY system_name,
		 from_package_name;
-- rows: 22513