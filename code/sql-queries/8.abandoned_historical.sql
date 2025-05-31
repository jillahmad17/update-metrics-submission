-- controlling abandoned packages MTTU and MTTR when the package gets abandoned


CREATE INDEX versioninfo_extended_index
ON versioninfo_extended (system_name, package_name, version_name, release_date);


CREATE TABLE abandoned_packages_extened_versioninfo AS
SELECT v.system_name,
	v.package_name,
	MAX(v.version_name) AS last_version,
	MAX(v.release_date) AS last_version_release_date,
	MIN(v.version_name) AS first_version,
	MIN(v.release_date) AS first_version_release_date
FROM versioninfo_extended v
INNER JOIN abandoned_packages a ON v.system_name = a.system_name AND v.package_name = a.package_name
WHERE a.isAbandoned = 1
GROUP BY v.system_name, v.package_name;
-- select 4102

CREATE INDEX abandoned_packages_extened_versioninfo_index
ON abandoned_packages_extened_versioninfo (system_name, package_name, last_version_release_date, first_version_release_date);


-- compute MTTU at historical data points, from the first version to the last version, for the abandoned packages
-- Write a query to compute the time_to_update value for each from_package_name and to_package_name pair
-- at different historical time. The historical times should start from when the first version of 
-- from_package_name was released to the last_version_release date of that packages. Store the historical time 
-- in a separate column. The last_version_release_date time should be considered as time 0 and first version
-- release date should be some negative number in time point.
CREATE TABLE historical_abandoned_time_to_update_from_to AS
SELECT arm.system_name,
		arm.from_package_name,
		arm.to_package_name,
		v.release_date AS historical_time,
		SUM(
			EXTRACT(DAYS FROM COALESCE(arm.interval_end, v.release_date) - arm.interval_start) -- counting till the historical time for each row
		) AS time_out_of_date
  FROM abandoned_relations_minified arm
  CROSS JOIN versioninfo_extended v
	WHERE arm.system_name = v.system_name
		AND arm.from_package_name = v.package_name
		AND v.release_date > arm.interval_start -- omitting the versions that were released after the interval start (>=)
		AND arm.isAbandoned = 1
 		AND arm.is_out_of_date = true 
   		AND arm.is_regular = true 
 GROUP BY arm.system_name,
          arm.from_package_name,
          arm.to_package_name,
		  v.release_date;
-- SELECT 818943

CREATE TABLE historical_abandoned_time_total_from_to AS
SELECT arm.system_name,
		arm.from_package_name,
		arm.to_package_name,
		v.release_date AS historical_time,
		SUM(
			EXTRACT(DAYS FROM COALESCE(arm.interval_end, v.release_date) - arm.interval_start) -- counting till the historical time for each row
		) AS total_time
  FROM abandoned_relations_minified arm
  CROSS JOIN versioninfo_extended v
	WHERE arm.system_name = v.system_name
		AND arm.from_package_name = v.package_name
		AND v.release_date > arm.interval_start -- omitting the versions that were released after the interval start (>=)
		AND arm.isAbandoned = 1
   		AND arm.is_regular = true 
 GROUP BY arm.system_name,
          arm.from_package_name,
          arm.to_package_name,
		  v.release_date;
-- SELECT 2026256


CREATE TABLE historical_abandoned_time_data_from_to_extended AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.historical_time,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM historical_abandoned_time_total_from_to E
LEFT JOIN historical_abandoned_time_to_update_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name
	AND E.historical_time = F.historical_time;
-- SELECT 2026256

CREATE TABLE historical_abandoned_mean_time_to_update_extended AS
SELECT system_name,
		from_package_name,
		historical_time,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM historical_abandoned_time_data_from_to_extended
WHERE total_time != 0
GROUP BY system_name,
		 from_package_name,
		 historical_time;
-- SELECT 120818


CREATE TABLE historical_abandoned_time_to_remediate_from_to AS
SELECT arm.system_name,
		arm.from_package_name,
		arm.to_package_name,
		v.release_date AS historical_time,
		SUM(
			EXTRACT(DAYS FROM COALESCE(arm.interval_end, v.release_date) - arm.interval_start) -- counting till the historical time for each row
		) AS time_out_of_date
  FROM abandoned_relations_minified arm
  CROSS JOIN versioninfo_extended v
	WHERE arm.system_name = v.system_name
		AND arm.from_package_name = v.package_name
		AND v.release_date > arm.interval_start -- omitting the versions that were released after the interval start (>=)
		AND arm.isAbandoned = 1
 		AND arm.is_out_of_date = true
		AND arm.is_exposed = true
   		AND arm.is_regular = true 
 GROUP BY arm.system_name,
          arm.from_package_name,
          arm.to_package_name,
		  v.release_date;
-- SELECT 19952

CREATE TABLE historical_abandoned_remediate_data_from_to_extended AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.historical_time,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_to_remediate,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM historical_abandoned_time_total_from_to E
LEFT JOIN historical_abandoned_time_to_remediate_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name
	AND E.historical_time = F.historical_time;
-- SELECT 2026256

CREATE TABLE historical_abandoned_mean_time_to_remediate_extended AS
SELECT system_name,
		from_package_name,
		historical_time,
		SUM(total_time) AS total_duration,
		SUM(time_to_remediate) AS total_post_fix_exposure_time,
		(SUM(time_to_remediate) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_to_remediate) AS avg_post_fix_exposure_time,
		(AVG(time_to_remediate) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM historical_abandoned_remediate_data_from_to_extended
WHERE total_time != 0 AND time_to_remediate != 0
GROUP BY system_name,
		 from_package_name,
		 historical_time;
-- SELECT 11426 

ALTER TABLE historical_abandoned_mean_time_to_update_extended 
ADD COLUMN time_from_last_version INTEGER;

UPDATE historical_abandoned_mean_time_to_update_extended h
SET time_from_last_version = EXTRACT(DAYS FROM (h.historical_time - a.last_version_release_date))
FROM abandoned_packages_extened_versioninfo a 
WHERE h.system_name = a.system_name 
AND h.from_package_name = a.package_name;
-- UPDATE 120818

ALTER TABLE historical_abandoned_mean_time_to_remediate_extended 
ADD COLUMN time_from_last_version INTEGER;

UPDATE historical_abandoned_mean_time_to_remediate_extended h
SET time_from_last_version = EXTRACT(DAYS FROM (h.historical_time - a.last_version_release_date))
FROM abandoned_packages_extened_versioninfo a 
WHERE h.system_name = a.system_name 
AND h.from_package_name = a.package_name;
-- UPDATE 11426

ALTER TABLE historical_abandoned_mean_time_to_update_extended 
RENAME COLUMN avg_out_of_date_duration TO mttu;

ALTER TABLE historical_abandoned_mean_time_to_remediate_extended 
RENAME COLUMN avg_post_fix_exposure_time TO mttr;

\COPY historical_abandoned_mean_time_to_update_extended TO '/home/imranur/security-metrics/data/historical_abandoned/historical_abandoned_mttu.csv' DELIMITER ',' CSV HEADER;

\COPY historical_abandoned_mean_time_to_remediate_extended TO '/home/imranur/security-metrics/data/historical_abandoned/historical_abandoned_mttr.csv' DELIMITER ',' CSV HEADER;