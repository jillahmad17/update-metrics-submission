CREATE TABLE post_fix_exposure_time_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM relations
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS post_fix_exposure_time
  FROM relations
 WHERE (warnings = '') IS NOT FALSE -- Don't count time out of date if a warning is present (missing timestamps etc.)
   AND is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
   AND is_exposed = true
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- took 20 min


-- we can simply use the 'time_total_from_to' from the 'time_out_of_date.sql' file.


CREATE TABLE post_fix_from_to AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.post_fix_exposure_time, 0) AS post_fix_exposure_time,
		COALESCE((F.post_fix_exposure_time / NULLIF(E.total_time, 0)), 0) AS percentage
FROM time_total_from_to E
LEFT JOIN post_fix_exposure_time_from_to F
ON E.system_name = F.system_name AND E.from_package_name = F.from_package_name AND E.to_package_name = F.to_package_name;
-- 15 sec


CREATE TABLE post_fix_exposure_time_combined AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(post_fix_exposure_time) AS total_post_fix_exposure_time,
		(SUM(post_fix_exposure_time) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(post_fix_exposure_time) AS avg_post_fix_exposure_time,
		(AVG(post_fix_exposure_time) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM post_fix_from_to
GROUP BY system_name,
		 from_package_name;
-- 10 sec



-- without unmaintained projects


CREATE TABLE post_fix_from_to_maintained AS
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
		COALESCE(F.post_fix_exposure_time, 0) AS post_fix_exposure_time,
		COALESCE((F.post_fix_exposure_time / NULLIF(E.total_time, 0)), 0) AS percentage
FROM time_total_from_to E
LEFT JOIN post_fix_exposure_time_from_to F
ON E.system_name = F.system_name AND E.from_package_name = F.from_package_name AND E.to_package_name = F.to_package_name-- AND F.post_fix_exposure_time != 0
INNER JOIN maintained H
ON E.system_name = H.system_name AND E.to_package_name = H.package_name; -- is this correct?
-- 44 sec


CREATE TABLE post_fix_exposure_time_combined_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(post_fix_exposure_time) AS total_post_fix_exposure_time,
		(SUM(post_fix_exposure_time) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(post_fix_exposure_time) AS avg_post_fix_exposure_time,
		(AVG(post_fix_exposure_time) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM post_fix_from_to
WHERE total_time != 0 AND post_fix_exposure_time != 0
GROUP BY system_name,
		 from_package_name;
-- 11 sec



-- relation between pfet and # of version releases
CREATE TABLE pfet_vs_versions AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.num_of_versions,
		AVG(avg_post_fix_exposure_time) AS avg_post_fix_exposure_time,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM post_fix_exposure_time_combined Y
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
-- 30 sec
		
	
	

-- relation between pfet and # of MAJOR version releases
CREATE TABLE pfet_vs_major_versions AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.num_of_major_versions,
		AVG(avg_post_fix_exposure_time) AS avg_post_fix_exposure_time,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM post_fix_exposure_time_combined Y
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
-- 8 sec


-- for testing purpose only
create table versioninfo_major as
select system_name,
		package_name,
		COUNT(DISTINCT(get_semver_major(version_name))) as num_of_major_versions
from versioninfo_extended
group by system_name,
		package_name;
		
		
select *
from versioninfo_major
where num_of_major_versions = 0;
		
select *
from versioninfo_extended
where system_name = 'NPM' and package_name = '@aloe2/abstract-eth';
		
		
		
-- find number of effective dependencies for each package
-- by 'effective' we mean # dependencies having pfet values
-- along with the 'dependents_approx' from Google
CREATE TABLE dependence_info_pfet AS
SELECT L.system_name, L.package_name, L.dependents_approx, N.dependencies_approx
FROM out_of_date_duration_google L
INNER JOIN 
(
	SELECT system_name, from_package_name, COUNT(to_package_name) AS dependencies_approx
	FROM post_fix_from_to
	GROUP BY system_name,
			from_package_name
) N
ON L.system_name = N.system_name AND L.package_name = N.from_package_name;
-- 8 sec



CREATE TABLE pfet_vs_dependencies AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.dependencies_approx,
		AVG(avg_post_fix_exposure_time) AS avg_post_fix_exposure_time,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM post_fix_exposure_time_combined Y
INNER JOIN dependence_info_pfet X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.dependencies_approx;
-- 1 sec
		

CREATE TABLE pfet_vs_dependents AS
-- SELECT X.system_name, X.package_name, X.num_of_versions, Y.total_duration, Y.out_of_date_duration, Y.ratio,
-- 		Y.avg_total_duration, Y.avg_out_of_date_duration, Y.avg_ratio
SELECT X.system_name,
		X.dependents_approx,
		AVG(avg_post_fix_exposure_time) AS avg_post_fix_exposure_time,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM post_fix_exposure_time_combined Y
INNER JOIN dependence_info X
ON X.system_name = Y.system_name AND X.package_name = Y.from_package_name
GROUP BY X.system_name,
		X.dependents_approx;
-- 1 sec


CREATE TABLE pfet_vs_age AS
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
		AVG(avg_post_fix_exposure_time) AS avg_out_of_date_duration,
		AVG(avg_ratio) AS avg_ratio,
		COUNT(from_package_name) AS frequency
FROM post_fix_exposure_time_combined E
INNER JOIN calc_age H
ON E.system_name = H.system_name AND E.from_package_name = H.package_name
GROUP BY H.system_name,
		H.lifetime_days;
-- 33 sec


CREATE TABLE pfet_of_critical AS
SELECT X.system_name,
		X.from_package_name,
		X.avg_post_fix_exposure_time,
		X.avg_total_duration,
		X.avg_ratio,
		Y.pagerank
FROM post_fix_exposure_time_combined X
INNER JOIN critical_projects Y
ON X.system_name = Y.system_name AND X.from_package_name = Y.package_name;
-- 1 sec