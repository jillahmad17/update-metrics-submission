-- rows at this point: 1582871841

-- change the data type of 'from_version' and 'to_version' column
alter table relations alter column from_version type semver using 
   case when is_semver(from_version) then semver(from_version) end;
-- took 21 min
-- table rows: 1087857158
   
alter table relations alter column to_version type semver using 
   case when is_semver(to_version) then semver(to_version) end;
-- took 30 mins
-- table rows: 1087857158
-- so, it didn't delete any rows.

create table versioninfo_backup as
select *
from versioninfo;
-- took 1 min

alter table versioninfo alter column version_name type semver using 
   case when is_semver(version_name) then semver(version_name) end;
-- took 1 min

-- in total (if together) 51 min



CREATE TABLE relations_regular AS
SELECT *
FROM relations
WHERE is_regular = true
-- took 12 min

ALTER TABLE relations ALTER COLUMN from_version TYPE varchar;
ALTER TABLE relations ALTER COLUMN to_version TYPE varchar;
ALTER TABLE versioninfo ALTER COLUMN version_name TYPE varchar;
-- took 25 min altogether.



   


-- (working) create a table of <frompackagename, fromversion, topackagename> records for exclusion later
-- don't need that anymore
CREATE TABLE exclude_records AS
SELECT R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name, COUNT(*) AS count_no
FROM relations R2
INNER JOIN versioninfo V3
ON R2.from_package_name = V3.package_name AND R2.from_version::text = V3.version_name::text AND R2.system_name = V3.system_name AND R2.is_regular = true
INNER JOIN versioninfo V4
ON R2.to_package_name = V4.package_name AND R2.to_version::text = V4.version_name::text AND R2.system_name = V4.system_name AND R2.is_regular = true
GROUP BY R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name
HAVING COUNT(*) > 1;




create table versioninfo_temp as 
select * from public.versioninfo
limit 1000;

-- to have the next version info with each version info
create table versioninfo_extended as
select V1.system_name, V1.package_name, V1.version_name, V1.release_date, 
lead(V1.version_name, 1) over (
	partition by V1.system_name, V1.package_name
	order by V1.version_name
) as next_version_name,
lead(V1.release_date, 1) over (
	partition by V1.system_name, V1.package_name
	order by V1.version_name
) as next_version_release_date
from versioninfo V1;


--DROP INDEX versioninfo_extended_index;
-- indexing for faster data retrieval
CREATE INDEX versioninfo_extended_index
ON versioninfo_extended (system_name, package_name, version_name, release_date);

CREATE INDEX versioninfo_backup_index
ON versioninfo_backup (system_name, package_name, version_name);

CREATE INDEX relations_index
ON relations (system_name, to_package_name);
--18 min


-- (working looks like) figure out the rows having meaningful ttu values
-- we have also removed duplicates and took only the highest version if multiple versions of the same package were listed as a dependency.
CREATE TABLE relations_with_all AS
--SELECT R1.system_name, R1.from_package_name, R1.from_version, V1.release_date AS from_package_release_date, R1.to_package_name, R1.to_version, V2.release_date AS to_package_release_date, R1.prev_from_version, R1.prev_to_version, V1.release_date - V2.release_date AS ttu, EXTRACT(days FROM V1.release_date - V2.release_date) AS ttu_in_days,
SELECT R1.system_name, R1.from_package_name, R1.from_version, V1.release_date AS from_package_release_date, R1.to_package_name, R1.actual_requirement, R1.to_version, V2.release_date AS to_package_release_date, R1.prev_from_version, R1.prev_to_version,
-- CASE
-- 	WHEN 
-- -- commented out the next few checking since we already know they should be same (because of the PARTITION BY)
-- -- 		R1.systemname = LAG(R1.systemname, 1) OVER (
-- -- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- -- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- -- 		) AND 
-- -- 		R1.frompackagename = LAG(R1.frompackagename, 1) OVER (
-- -- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- -- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- -- 		) AND 
-- 		R1.from_version::text != LAG(R1.from_version::text, 1) OVER (
-- 			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
-- 			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
-- 		) AND 
-- -- 		R1.topackagename = LAG(R1.topackagename, 1) OVER (
-- -- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- -- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- -- 		) AND 
-- 		R1.to_version::text != LAG(R1.to_version::text, 1) OVER (
-- 			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
-- 			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
-- 		)
-- 		THEN 1
-- 	ELSE NULL -- first row in the GROUP
-- 	-- WHEN LAG(ttu_in_days, 1, 0) OVER (ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate)
-- END AS is_appropriate,
CASE
-- 	WHEN R1.from_version != R1.prev_from_version AND R1.to_version > R1.prev_to_version
-- 		THEN V1.release_date - (
-- 				select next_version_release_date
-- 				from public.versioninfo_extended
-- 				where system_name = R1.system_name
-- 				and package_name = R1.to_package_name
-- 				and version_name = R1.prev_to_version
-- 				order by version_name
-- 				limit 1
-- 			) -- need to find the immediate next version than previous 'to_version'
-- 		--)
-- 	WHEN R1.from_version != R1.prev_from_version AND R1.to_version < R1.prev_to_version
-- 		THEN V1.release_date - V2.release_date
	WHEN R1.from_version != R1.prev_from_version
		THEN
			CASE
				WHEN R1.to_version > R1.prev_to_version
					THEN V1.release_date - (
						select next_version_release_date
						from public.versioninfo_extended
						where system_name = R1.system_name
						and package_name = R1.to_package_name
						and version_name = R1.prev_to_version
						order by version_name
						limit 1
					) -- need to find the immediate next version than previous 'to_version'
				WHEN R1.to_version < R1.prev_to_version -- downgrade case
					THEN V1.release_date - V2.release_date
				END
	ELSE NULL
END AS valid_ttu
FROM 
(
	SELECT *,
	LAG(R2.to_version, 1) OVER (
				PARTITION BY R2.system_name, R2.from_package_name, R2.to_package_name--, R1.toversion, toreleasedate
				ORDER BY R2.system_name, R2.from_package_name, R2.to_package_name, R2.from_version, R2.to_version
	) AS prev_to_version,

	LAG(R2.from_version, 1) OVER (
				PARTITION BY R2.system_name, R2.from_package_name, R2.to_package_name--, R1.toversion, toreleasedate
				ORDER BY R2.system_name, R2.from_package_name, R2.to_package_name, R2.from_version, R2.to_version
	) AS prev_from_version
	FROM (
		SELECT *, 
				ROW_NUMBER() OVER(PARTITION BY R3.system_name, 
										 R3.from_package_name, 
										 R3.from_version,
										 R3.to_package_name
				ORDER BY R3.to_version DESC) row_num
		FROM relations R3
		WHERE R3.is_regular = true
	) AS R2
	WHERE R2.row_num = 1
) AS R1
INNER JOIN versioninfo_extended V1
ON  R1.from_package_name = V1.package_name AND R1.from_version::text = V1.version_name::text AND R1.system_name = V1.system_name-- AND R1.is_regular = true
INNER JOIN versioninfo_extended V2
ON R1.to_package_name = V2.package_name AND R1.to_version::text = V2.version_name::text AND R1.system_name = V2.system_name-- AND R1.is_regular = true
--WHERE R1.row_num = 1
GROUP BY R1.system_name, R1.from_package_name, R1.from_version, from_package_release_date, R1.to_package_name, R1.to_version, to_package_release_date, R1.prev_from_version, R1.prev_to_version, R1.actual_requirement
--ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, frompackagereleasedate;
ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version;
-- took 53min


create table relations_test as
select *
from public.relations
limit 1000;


select *
from public.relations_with_all
limit 2000;
-- total: 223 mil rows



-- number of appropriate TTU values
SELECT COUNT(*)
FROM relations_with_all
WHERE is_appropriate is not null;
-- output: 21 million

-- export table
CREATE TABLE ttu_table_without_dev AS
SELECT system_name, from_package_name, EXTRACT(YEAR FROM from_package_release_date) AS year_, EXTRACT(DAY FROM valid_ttu) as valid_ttu_in_days
FROM relations_with_all
WHERE valid_ttu is not null;
-- 55 sec

SELECT COUNT(*)
FROM relations_with_all
WHERE is_appropriate is not null
AND ttu_in_days = 0;
-- 10 million

-- find out the critical projects having negative ttu_values
SELECT *
FROM relations_with_all r
INNER JOIN critical_projects c
ON r.system_name = c.system_name AND r.from_package_name = c.package_name AND r.valid_ttu is not null AND extract(day from r.valid_ttu) < 0;
-- 36k

select system_name, count(distinct from_package_name)
from relations_with_all
where is_appropriate is not null
group by system_name;
-- 493k

select * from public.exclude_records
limit 1000;