-- scp to download from remote
-- scp -P 42111 imranur@152.14.199.163:/home/imranur/security-metrics/data/nz/mttr.csv ~/Downloads/

-- scp to upload to remote
-- scp -P 42111 ~/Research/courtney-icse25/data/widelyUsednpmPackages.csv imranur@152.14.199.163:/home/imranur/


create table abandoned_packages (
 npmPackageName VARCHAR(255),
 slug VARCHAR(255),
 repoArchived INT,
 READMEKeyword INT,
 READMEBadge VARCHAR(255),
 activityBasedAbandoned INT,
 maxNumDownloads INT,
 isAbandoned INT,
 numStars VARCHAR(255)
);

\copy abandoned_packages FROM '/home/imranur/widelyUsednpmPackages.csv' csv header;
-- COPY 28100

alter table abandoned_packages add column system_name VARCHAR(255) default 'NPM';
alter table abandoned_packages rename column npmPackageName to package_name;

create index abandoned_packages_index
on abandoned_packages (system_name, package_name, isAbandoned);

CREATE TABLE abandoned_relations_minified AS
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
		r.is_regular,
		s1.isAbandoned
FROM relations r
INNER JOIN abandoned_packages s1
ON r.system_name = s1.system_name AND r.from_package_name = s1.package_name;
-- SELECT 56167019

CREATE INDEX abandoned_relations_minified_index
ON abandoned_relations_minified (system_name,
				to_package_name,
				to_version,
				interval_start,
				isAbandoned,
				is_regular);

alter table abandoned_relations_minified add column is_exposed boolean default false;

UPDATE abandoned_relations_minified r
SET is_exposed = true
FROM osv_extended o
WHERE r.system_name = o.system_name
	AND r.to_package_name = o.package_name
	AND o.fixed_version_release_date <= r.interval_start
	AND o.vul_introduced <= r.to_version
	AND r.to_version < o.vul_fixed;
-- UPDATE 839934

CREATE INDEX abandoned_relations_minified_index_2
ON abandoned_relations_minified (system_name,
				from_package_name,
				to_package_name,
				is_out_of_date,
				is_regular,
				is_exposed);

-- testing
SELECT DISTINCT system_name
FROM nz_relations_minified;


CREATE TABLE abandoned_time_to_update_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM abandoned_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM abandoned_relations_minified
 WHERE is_out_of_date = true -- Only when the requirement was out of date
   AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- SELECT 98677

CREATE TABLE abandoned_time_total_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM abandoned_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS total_time
  FROM abandoned_relations_minified
 WHERE is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- SELECT 177208

CREATE TABLE abandoned_time_data_from_to_maintained AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_out_of_date,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage,
		G.isAbandoned
FROM abandoned_time_total_from_to E
INNER JOIN abandoned_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN abandoned_time_to_update_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- SELECT 177208


CREATE TABLE abandoned_mean_time_to_update_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_out_of_date) AS out_of_date_duration,
		(SUM(time_out_of_date) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_out_of_date) AS avg_out_of_date_duration,
		(AVG(time_out_of_date) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM abandoned_time_data_from_to_maintained
WHERE total_time != 0
GROUP BY system_name,
		 from_package_name;
-- SELECT 21670

-- testing for duplicates
SELECT system_name, from_package_name, COUNT(*)
from abandoned_mean_time_to_update_maintained
GROUP BY system_name, from_package_name
HAVING COUNT(*) > 1;
-- No duplicates found

-- testing
SELECT count(*)
FROM abandoned_mean_time_to_update_maintained t
WHERE NOT EXISTS (SELECT NULL
					FROM abandoned_packages s
					WHERE t.system_name = s.system_name
						AND t.from_package_name = s.package_name);

-- testing
SELECT count(*)
FROM abandoned_selected_packages t
WHERE NOT EXISTS (SELECT NULL
					FROM abandoned_mean_time_to_update_maintained s
					WHERE s.system_name = t.system_name
						AND s.from_package_name = t.package_name);

-- testing
SELECT DISTINCT system_name
FROM abandoned_mean_time_to_update_maintained;


CREATE TABLE abandoned_time_to_remediate_from_to AS
WITH highest AS (
	SELECT MAX(interval_start) as db_creation_date
	FROM abandoned_relations_minified
)
SELECT system_name,
		from_package_name,
		to_package_name,
		SUM(
			EXTRACT(DAYS FROM COALESCE(interval_end, (select db_creation_date from highest)) - interval_start)
		) AS time_out_of_date
  FROM abandoned_relations_minified
 WHERE is_out_of_date = true -- Only when the requirement was out of date
    AND is_exposed = true
    AND is_regular = true -- Don't count dev dependencies (maybe you want to?)
 GROUP BY system_name,
          from_package_name,
          to_package_name;
-- rows: 6971


CREATE TABLE abandoned_remediate_data_from_to_maintained AS
SELECT E.system_name,
		E.from_package_name,
		E.to_package_name,
		E.total_time,
		COALESCE(F.time_out_of_date, 0) AS time_to_remediate,
		COALESCE((F.time_out_of_date / NULLIF(E.total_time, 0)), 0) AS percentage_ttr
FROM abandoned_time_total_from_to E
INNER JOIN abandoned_packages G
ON E.system_name = G.system_name 
	AND E.from_package_name = G.package_name -- restricting to only packages that are maintained
LEFT JOIN abandoned_time_to_remediate_from_to F
ON E.system_name = F.system_name 
	AND E.from_package_name = F.from_package_name 
	AND E.to_package_name = F.to_package_name;
-- pretty fast
-- rows: 177208


CREATE TABLE abandoned_mean_time_to_remediate_maintained AS
SELECT system_name,
		from_package_name,
		SUM(total_time) AS total_duration,
		SUM(time_to_remediate) AS total_post_fix_exposure_time,
		(SUM(time_to_remediate) / NULLIF(SUM(total_time), 0)) AS ratio,
		AVG(total_time) AS avg_total_duration,
		AVG(time_to_remediate) AS avg_post_fix_exposure_time,
		(AVG(time_to_remediate) / NULLIF(AVG(total_time), 0)) AS avg_ratio
FROM abandoned_remediate_data_from_to_maintained
WHERE total_time != 0 AND time_to_remediate != 0
GROUP BY system_name,
		 from_package_name;
-- rows: 4186

SELECT count(*)
FROM abandoned_mean_time_to_remediate_maintained t
WHERE NOT EXISTS (SELECT NULL
					FROM abandoned_selected_packages s
					WHERE t.system_name = s.system_name
						AND t.from_package_name = s.package_name);

SELECT count(*)
FROM abandoned_selected_packages t
WHERE NOT EXISTS (SELECT NULL
					FROM abandoned_mean_time_to_remediate_maintained s
					WHERE s.system_name = t.system_name
						AND s.from_package_name = t.package_name);


`\copy (select * from abandoned_mean_time_to_update_maintained) to '/home/imranur/security-metrics/data/abandoned/mttu.csv' with header delimiter as ','` (count: 21670) and
`\copy (select * from abandoned_mean_time_to_remediate_maintained) to '/home/imranur/security-metrics/data/abandoned/mttr.csv' with header delimiter as ','` (count: 4186)


