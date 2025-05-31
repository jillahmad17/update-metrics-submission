SELECT *
FROM relationwithdowngrade
WHERE systemname='CARGO' AND frompackagename='adler' AND topackagename='criterion';

SELECT *
FROM relationwithdowngrade
WHERE systemname='CARGO' AND frompackagename='aph-cli' AND topackagename='aph';

SELECT *
FROM relationwithdowngrade
WHERE systemname='CARGO' AND frompackagename='clyde' AND topackagename='semver';

SELECT *
FROM versioninfo
WHERE systemname='CARGO';
-- Result: versioninfo does not have any CARGO package information
-- Reason behind problem: I didn't use systemname with INNER JOIN


-- testing: keep the highest version of a dependency if multiple versions exist at the same time
-- (working) create a table of <frompackagename, fromversion, topackagename> records for exclusion later
CREATE TABLE exclude_records_test AS
SELECT R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name, COUNT(*) AS count_no
FROM relations_test R2
INNER JOIN versioninfo V3
ON R2.from_package_name = V3.package_name AND R2.from_version::text = V3.version_name::text AND R2.system_name = V3.system_name AND R2.is_regular = true
INNER JOIN versioninfo V4
ON R2.to_package_name = V4.package_name AND R2.to_version::text = V4.version_name::text AND R2.system_name = V4.system_name AND R2.is_regular = true
GROUP BY R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name
HAVING COUNT(*) > 1;



-- 
SELECT R1.system_name, R1.from_package_name, R1.from_version, R1.to_package_name, R1.to_version--, R3.rank_
FROM relations_test R1
  INNER JOIN
(
 SELECT *, 
        RANK() OVER(PARTITION BY R2.system_name, 
                                 R2.from_package_name, 
                                 R2.from_version,
								 R2.to_package_name
        ORDER BY R2.to_version DESC) rank_
 FROM relations_test R2
) R3 ON R1.system_name = R3.system_name AND R1.from_package_name = R3.from_package_name AND R1.from_version = R3.from_version and R1.to_package_name = R3.to_package_name;



-- for showing multiple versions of the same dependency
SELECT R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version, R3.row_num
FROM
(
	SELECT *, 
			ROW_NUMBER() OVER(PARTITION BY R2.system_name, 
									 R2.from_package_name, 
									 R2.from_version,
									 R2.to_package_name
			ORDER BY R2.to_version DESC) row_num
	FROM relations_test R2
	WHERE R2.is_regular = true
) AS R3
--WHERE R3.row_num = 1
GROUP BY R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version, R3.row_num
ORDER BY R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version, R3.row_num;


SELECT R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version, R3.row_num
FROM
(
	SELECT *, 
			ROW_NUMBER() OVER(PARTITION BY R2.system_name, 
									 R2.from_package_name, 
									 R2.from_version,
									 R2.to_package_name
			ORDER BY R2.to_version DESC) row_num
	FROM relations_test R2
	WHERE R2.is_regular = true
) AS R3
WHERE R3.row_num = 1
GROUP BY R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version, R3.row_num
ORDER BY R3.system_name, R3.from_package_name, R3.from_version, R3.to_package_name, R3.to_version;
-- we are using row_number() instead of rank() because rank would mark all duplicates in the same group as the same number.








-- (working looks like) figure out the rows having meaningful ttu values
CREATE TABLE relations_with_all_test AS
SELECT R1.system_name, R1.from_package_name, R1.from_version, V1.release_date AS from_package_release_date, R1.to_package_name, R1.to_version, V2.release_date AS to_package_release_date, V1.release_date - V2.release_date AS ttu, EXTRACT(days FROM V1.release_date - V2.release_date) AS ttu_in_days,
CASE
	WHEN 
-- commented out the next few checking since we already know they should be same (because of the PARTITION BY)
-- 		R1.systemname = LAG(R1.systemname, 1) OVER (
-- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- 		) AND 
-- 		R1.frompackagename = LAG(R1.frompackagename, 1) OVER (
-- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- 		) AND 
		R1.from_version::text != LAG(R1.from_version::text, 1) OVER (
			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
		) AND 
-- 		R1.topackagename = LAG(R1.topackagename, 1) OVER (
-- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- 		) AND 
		R1.to_version::text != LAG(R1.to_version::text, 1) OVER (
			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
		)
		THEN 1
	ELSE NULL -- first row in the GROUP
	-- WHEN LAG(ttu_in_days, 1, 0) OVER (ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate)
END AS is_appropriate
FROM 
(
	SELECT *, 
			ROW_NUMBER() OVER(PARTITION BY R2.system_name, 
									 R2.from_package_name, 
									 R2.from_version,
									 R2.to_package_name
			ORDER BY R2.to_version DESC) row_num
	FROM relations_test R2
) AS R1
INNER JOIN versioninfo V1
ON  R1.from_package_name = V1.package_name AND R1.from_version::text = V1.version_name::text AND R1.system_name = V1.system_name AND R1.is_regular = true
INNER JOIN versioninfo V2
ON R1.to_package_name = V2.package_name AND R1.to_version::text = V2.version_name::text AND R1.system_name = V2.system_name AND R1.is_regular = true
-- WHERE NOT EXISTS (
-- 	SELECT *
-- 	FROM exclude_records E1
-- 	WHERE E1.system_name = R1.system_name AND E1.from_package_name = R1.from_package_name AND E1.from_version::text = R1.from_version::text AND E1.to_package_name = R1.to_package_name
-- )
WHERE R1.row_num = 1
GROUP BY R1.system_name, R1.from_package_name, R1.from_version, from_package_release_date, R1.to_package_name, R1.to_version, to_package_release_date
--ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, frompackagereleasedate;
ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version;
-- took 1h 17min











create table exclude_records_test_with_version as
select R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name, R2.to_version,
	row_number() over(partition by R2.system_name, R2.from_package_name, R2.from_version, R2.to_package_name ORDER BY R2.to_version desc) AS row_number_
from relations_test R2
inner join versioninfo V3
on R2.from_package_name = V3.package_name and R2.from_version::text = V3.version_name::text and R2.system_name = V3.system_name and R2.is_regular = true
inner join versioninfo V4
on R2.to_package_name = V4.package_name and R2.to_version::text = V4.version_name::text and R2.system_name = V4.system_name and R2.is_regular = true
where exists (
	select *
	from exclude_records_test E1
	where E1.system_name = R2.system_name and E1.from_package_name = R2.from_package_name and E1.from_version::text = R2.from_version::text and E1.to_package_name = R2.to_package_name
);
--and row_number_ > 1;



select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'swagger-ui';


select *
from relations_with_all
where system_name = 'NPM' and from_package_name = '@ditsmod/openapi' and from_version = '2.9.0' and to_package_name = 'swagger-ui';

select *
from relations
where system_name = 'NPM' and from_package_name = '@ditsmod/openapi' and from_version = '2.9.0' and to_package_name = 'swagger-ui';


select *
from versioninfo_extended
where system_name = 'NPM' and package_name = 'swagger-ui';

select *
from versioninfo_extended
where system_name = 'NPM' and package_name = '@arkecosystem/core-container';






select *
from public.relations
where system_name = 'NPM'
and from_package_name = 'ct-mss-ui'
and to_package_name = 'eslint-loader';


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = 'ct-mapapps-gulp-js'
and to_package_name = 'gulp'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start;


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
from public.relations_minified
where system_name = 'PYPI'
and from_package_name = '0x-contract-wrappers'
and to_package_name = '0x-contract-addresses'
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
order by interval_start;


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
from public.relations
where system_name = 'NPM'
and from_package_name = 'ct-oauth-plugin'
--and to_package_name = 'gulp'
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
order by to_package_name, from_version, interval_start;


-- to check the downgrade case
select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
from public.relations
where system_name = 'NPM'
and from_package_name = 'now-client'
and to_package_name = 'request'
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end
order by interval_start;



-- this is showing some cases james described
-- needs 2 mins to run
select *
from public.relations
where system_name = 'NPM'
and to_package_name = 'urijs'
and to_version >= '0.0.0'
and to_version < '1.19.6';

select next_version_name, next_version_release_date
from public.versioninfo_extended
where system_name = 'NPM'
and package_name = '@babel/plugin-proposal-numeric-separator'
and version_name = '7.14.5'
order by version_name
limit 1;


select *
from public.versioninfo_extended
where system_name = 'PYPI'
and package_name = 'numpy';

-- for the paper
select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed, is_regular
from public.relations
where system_name = 'NPM'
and from_package_name = '1257-server'
and to_package_name = 'mysql'
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed, is_regular
order by to_package_name, from_version, interval_start;

-- for the paper
select *
from public.versioninfo_extended
where system_name = 'NPM'
and package_name = '-tompan-reacttemplate';

-- for the paper, motivating example
select system_name, from_package_name, from_version, from_package_release_date, to_package_name, actual_requirement, to_version, to_package_release_date, valid_ttu
from public.relations_with_all
where system_name = 'NPM'
and from_package_name = 'mongodb'
and to_package_name = 'bson'
group by system_name, from_package_name, from_version, from_package_release_date, to_package_name, actual_requirement, to_version, to_package_release_date, valid_ttu
order by to_package_name, from_version;



-- for the new paper
select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = '@alephium/web3'
and to_package_name = 'elliptic'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start;


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = '@antora/page-composer'
and to_package_name = 'handlebars'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start;


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = '@arkecosystem/core-kernel'
and to_package_name = 'semver'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start;


select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = '@atlaskit/codemod-cli'
and to_package_name = 'simple-git'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start;


\copy (select system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
from public.relations_minified
where system_name = 'NPM'
and from_package_name = '@atlaskit/codemod-cli'
and to_package_name = 'simple-git'
and is_regular = true
group by system_name, from_package_name, from_version, to_package_name, actual_requirement, to_version, to_package_highest_available_release, interval_start, interval_end, is_out_of_date, is_exposed
order by interval_start) to '~/running_example.csv' delimiter ',' csv header