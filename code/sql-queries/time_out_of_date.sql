-- obsolete
CREATE TABLE time_out_of_date AS
SELECT system_name,
       from_package_name,
       from_version,
       SUM(EXTRACT(DAYS FROM 
         COALESCE(interval_end, LOCALTIMESTAMP) - interval_start)) AS time_out_of_date
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          from_version;
	

WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT *
FROM highest;

		  

CREATE TABLE time_out_of_date_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- 26 min


CREATE TABLE time_total_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS total_time
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
--   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
		  
		  
CREATE TABLE time_data_from_to AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM time_total_from_to E
LEFT JOIN time_out_of_date_from_to F
ON E.system_name = F.system_name AND E.from_package_name = F.from_package_name AND E.to_package_name = F.to_package_name;
-- 15 sec

--DROP TABLE public.time_data_from_to;
--DROP TABLE public.time_out_of_date_combined;
SELECT *
FROM time_data_from_to
WHERE time_out_of_date IS NULL;



CREATE TABLE time_out_of_date_combined AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM time_data_from_to
GROUP BY system_name,
		 from_package_name;
		 
		 
		 
		 
		 
-- without unmaintained projects


SELECT DISTINCT(system_name)
FROM versioninfo_extended
GROUP BY system_name;

-- find packages having first and last release difference more than 30 days
SELECT *
FROM (
	SELECT system_name, package_name, MAX(release_date) - MIN(release_date) as lifetime, COUNT(version_name) as num_versions
	FROM versioninfo_extended
	GROUP BY system_name, package_name
) AS x
WHERE EXTRACT(DAY FROM lifetime) > 30 and num_versions > 5;
-- 17 sec



CREATE TABLE time_data_from_to_maintained AS
WITH maintained AS (
	SELECT system_name, package_name
	FROM (
		SELECT system_name, package_name, MAX(release_date) - MIN(release_date) as lifetime, COUNT(version_name) as num_versions
		FROM versioninfo_extended
		GROUP BY system_name, package_name
	) AS x
	WHERE EXTRACT(DAY FROM lifetime) > 30 and num_versions > 5
)
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage
FROM time_total_from_to E
LEFT JOIN time_out_of_date_from_to F
ON E.system_name = F.system_name AND E.from_package_name = F.from_package_name AND E.to_package_name = F.to_package_name
INNER JOIN maintained H
ON E.system_name = H.system_name AND E.to_package_name = H.package_name;
-- 43 sec

CREATE TABLE time_out_of_date_combined_maintained AS
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
-- 8 sec





-- aggresive time out of date calculation
CREATE TABLE time_out_of_date_combined_aggr AS
SELECT system_name,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM time_data_from_to
WHERE time_out_of_date != 0
GROUP BY system_name,
		 from_package_name;
		 
		 
		 
		 

-- relation between tofd and # of version releases
CREATE TABLE tofd_vs_versions AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.num_of_versions,
		AVG(avg_out_of_date_duration) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM time_out_of_date_combined Y
INNER JOIN
(
	select system_name,
			package_name,
			COUNT(release_date) as num_of_versions
	from versioninfo_extended
	group by system_name,
			package_name
) X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.num_of_versions;
-- 32 sec
		
	
	

-- relation between tofd and # of MAJOR version releases
CREATE TABLE tofd_vs_major_versions AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.num_of_major_versions,
		AVG(avg_out_of_date_duration) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM time_out_of_date_combined Y
INNER JOIN
(
	select system_name,
			package_name,
			COUNT(DISTINCT(get_semver_major(version_name))) as num_of_major_versions
	from versioninfo_extended
	group by system_name,
			package_name
) X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.num_of_major_versions;
-- 13 sec


-- select system_name,
-- 		package_name,
-- 		COUNT(DISTINCT(get_semver_major(version_name))) as num_of_major_versions
-- from versioninfo_extended
-- group by system_name,
-- 		package_name;
		
-- select *
-- from versioninfo_extended
-- where system_name = 'NPM' and package_name = '--fix-lockfile';
		
		
		
-- find number of effective dependencies for each package
-- by 'effective' we mean # dependencies having tofd values
-- along with the 'dependents_approx' from Google
CREATE TABLE dependence_info AS
SELECT L.system_name, L.package_name, L.dependents_approx, N.dependencies_approx
FROM out_of_date_duration_google L
INNER JOIN 
(
	SELECT system_name, from_package_name, COUNT(to_package_name) AS dependencies_approx
	FROM time_data_from_to
	GROUP BY system_name,
			from_package_name
) N
ON L.system_name = N.system_name AND L.package_name = N.from_package_name;
-- 5 sec



CREATE TABLE tofd_vs_dependencies AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.dependencies_approx,
		AVG(avg_out_of_date_duration) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM time_out_of_date_combined Y
INNER JOIN dependence_info X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.dependencies_approx;
-- 1 sec
		
		

CREATE TABLE tofd_vs_dependents AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.dependents_approx,
		AVG(avg_out_of_date_duration) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM time_out_of_date_combined Y
INNER JOIN dependence_info X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.dependents_approx;
-- 1 sec



CREATE TABLE tofd_vs_age AS
WITH calc_age AS (
	SELECT system_name, package_name, EXTRACT(DAY FROM lifetime) as lifetime_days
	FROM (
		SELECT system_name, package_name, MAX(release_date) - MIN(release_date) as lifetime, COUNT(version_name) as num_versions
		FROM versioninfo_extended
		GROUP BY system_name, package_name
	) AS x
	WHERE EXTRACT(DAY FROM lifetime) > 0
)
SELECT H.system_name,
		H.lifetime_days,
		AVG(avg_out_of_date_duration) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM time_out_of_date_combined E
INNER JOIN calc_age H
ON E.system_name = H.system_name AND E.from_package_name = H.package_name
GROUP BY H.system_name,
		H.lifetime_days;
-- 33 sec


CREATE TABLE tofd_of_critical AS
SELECT X.system_name,
		X.from_package_name,
		X.avg_out_of_date_duration,
		X.avg_total_duration,
		X.avg_ratio,
		Y.pagerank
FROM time_out_of_date_combined X
INNER JOIN critical_projects Y
ON X.system_name = Y.system_name AND X.from_package_name = Y.package_name;
-- 1 sec