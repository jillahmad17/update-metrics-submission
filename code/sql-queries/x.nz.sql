-- scp to download from remote
-- scp -P 42111 imranur@152.14.199.163:/home/imranur/security-metrics/data/nz/mttr.csv ~/Downloads/

-- scp to upload to remote
-- scp -P 42111 ~/Research/courtney-icse25/data/widelyUsednpmPackages.csv imranur@152.14.199.163:/home/imranur/


create table nz_selected_packages (
 Name VARCHAR(255),
 URL VARCHAR(255),
 Version VARCHAR(255)
);

\copy nz_selected_packages FROM '/home/imranur/npm_have_dependencies_and_dependents.csv' csv header;
-- COPY 264413

alter table nz_selected_packages add column system_name VARCHAR(255) default 'NPM';
alter table nz_selected_packages rename column Name to package_name;
alter table nz_selected_packages rename column Version to version_name;

create index nz_selected_packages_index
on nz_selected_packages (system_name, package_name, version_name);

CREATE TABLE nz_relations_minified AS
SELECT r.system_name,
		r.from_package_name,
		r.from_version,
		r.to_package_name,
		r.actual_requirement,
		r.to_version,
		r.to_package_highest_available_release,
		r.interval_start,
		r.interval_end,
		r.is_out_of_date,
		r.is_regular
FROM relations r
INNER JOIN nz_selected_packages s1
ON r.system_name = s1.system_name AND r.from_package_name = s1.package_name
-- INNER JOIN nz_selected_packages s2
-- ON r.system_name = s2.system_name AND r.to_package_name = s2.package_name
;
-- SELECT 255639297

CREATE INDEX nz_relations_minified_index
ON nz_relations_minified (system_name,
				to_package_name,
				to_version,
				interval_start);

alter table nz_relations_minified add column is_exposed boolean default false;

UPDATE nz_relations_minified r
SET is_exposed = true
FROM osv_extended o
WHERE r.system_name = o.system_name
	AND r.to_package_name = o.package_name
	AND o.fixed_version_release_date <= r.interval_start
	AND o.vul_introduced <= r.to_version
	AND r.to_version < o.vul_fixed;
-- UPDATE 3669826

CREATE INDEX nz_relations_minified_index_2
ON nz_relations_minified (system_name,
				from_package_name,
				to_package_name,
				is_out_of_date,
				is_regular,
				is_exposed);

-- testing
SELECT DISTINCT system_name
FROM nz_relations_minified;


CREATE TABLE nz_time_to_update_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM nz_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM nz_relations_minified
 WHERE is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- SELECT 812074

CREATE TABLE nz_time_total_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM nz_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS total_time
  FROM nz_relations_minified
 WHERE is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- SELECT 1623378

CREATE TABLE nz_time_data_from_to_maintained AS
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
FROM nz_time_total_from_to E
-- INNER JOIN nz_selected_packages H
-- ON E.system_name = H.system_name 
-- 	AND E.to_package_name = H.package_name -- restricting to only packages that are maintained as dependencies
INNER JOIN nz_selected_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN nz_time_to_update_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- SELECT 1623378


CREATE TABLE nz_mean_time_to_update_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM nz_time_data_from_to_maintained
WHERE total_time != 0
GROUP BY system_name,
		 from_package_name;
-- SELECT 248820

-- testing for duplicates
SELECT system_name, from_package_name, COUNT(*)
from nz_mean_time_to_update_maintained
GROUP BY system_name, from_package_name
HAVING COUNT(*) > 1;
-- No duplicates found

-- testing
SELECT count(*)
FROM nz_mean_time_to_update_maintained t
WHERE NOT EXISTS (SELECT NULL
					FROM nz_selected_packages s
					WHERE t.system_name = s.system_name
						AND t.from_package_name = s.package_name);

-- testing
SELECT count(*)
FROM nz_selected_packages t
WHERE NOT EXISTS (SELECT NULL
					FROM nz_mean_time_to_update_maintained s
					WHERE s.system_name = t.system_name
						AND s.from_package_name = t.package_name);

-- testing
SELECT DISTINCT system_name
FROM nz_mean_time_to_update_maintained;


CREATE TABLE nz_time_to_remediate_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM nz_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM nz_relations_minified
 WHERE is_out_of_date = true -- Only when the requirement was out of date
    AND is_exposed = true
    AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- rows: 46715


CREATE TABLE nz_remediate_data_from_to_maintained AS
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
FROM nz_time_total_from_to E
-- INNER JOIN nz_selected_packages H
-- ON E.system_name = H.system_name 
-- 	AND E.to_package_name = H.package_name -- restricting to only packages that are maintained as dependencies
INNER JOIN nz_selected_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN nz_time_to_remediate_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- rows: 990839


CREATE TABLE nz_mean_time_to_remediate_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_to_remediate) AS total_post_fix_exposure_time,
		(SUM(time_to_remediate) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_to_remediate) AS avg_post_fix_exposure_time,
		(AVG(time_to_remediate) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM nz_remediate_data_from_to_maintained
WHERE total_time != 0 AND time_to_remediate != 0
GROUP BY system_name,
		 from_package_name;
-- rows: 33140

SELECT count(*)
FROM nz_mean_time_to_remediate_maintained t
WHERE NOT EXISTS (SELECT NULL
					FROM nz_selected_packages s
					WHERE t.system_name = s.system_name
						AND t.from_package_name = s.package_name);

SELECT count(*)
FROM nz_selected_packages t
WHERE NOT EXISTS (SELECT NULL
					FROM nz_mean_time_to_remediate_maintained s
					WHERE s.system_name = t.system_name
						AND s.from_package_name = t.package_name);


`\copy (select * from nz_mean_time_to_update_maintained) to '/home/imranur/security-metrics/data/nz/mttu.csv' with header delimiter as ','` (count: 248820) and
`\copy (select * from nz_mean_time_to_remediate_maintained) to '/home/imranur/security-metrics/data/nz/mttr.csv' with header delimiter as ','` (count: 33140)