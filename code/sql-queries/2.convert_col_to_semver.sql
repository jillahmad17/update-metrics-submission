- change the data type of 'from_version' and 'to_version' column
alter table relations alter column from_version type semver using 
   case when is_semver(from_version) then semver(from_version) end;
-- took 21 min
-- table rows: 1582871841
   
alter table relations alter column to_version type semver using 
   case when is_semver(to_version) then semver(to_version) end;
-- took 30 mins
-- table rows: 1582871841

-- If we do it here, it starts causing errors in creating osv_extended table.
-- alter table versioninfo alter column version_name type semver using 
--    case when is_semver(version_name) then semver(version_name) end;


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
-- columns: 53234376


-- ERROR:  bad semver value '1.0.20230603010803': version number exceeds 31-bit range

\copy (
	SELECT system_name, package_name, 
		   COUNT(version_name) as version_count,
		   DATE_PART('day', MAX(release_date) - MIN(release_date)) as package_age_days,
		   COUNT(DISTINCT CASE WHEN is_semver(version_name) THEN get_semver_major(to_semver(version_name)) END) as major_version_count
	FROM versioninfo
	GROUP BY system_name, package_name
	ORDER BY system_name, package_name
) TO '/home/imranur/security-metrics/data/versions_major_versions_age.csv' WITH CSV HEADER;
-- COPY 4090125