-- checking unique systemname in the dataset
SELECT DISTINCT system_name
FROM relations;

-- checking number of packages in each ecosystem
SELECT system_name, COUNT(DISTINCT package_name)
FROM versioninfo_extended
GROUP BY system_name;
-- CARGO 137319
-- NPM 2448781
-- PYPI 356971

-- checking total number of versions of all packages
SELECT system_name, COUNT(*)
FROM versioninfo_extended
GROUP BY system_name;
-- "CARGO"	28346565
-- "NPM"	34723685
-- "PYPI"	3827478

-- checking AVG number of versions each package has in each ecosystem
SELECT systemname, COUNT(*) / COUNT(DISTINCT packagename)
FROM versioninfo
GROUP BY systemname;

-- TODO: similarly calculate with and without dev-dependencies.

-- checking earlier and latest version release date of any package version for each ecosystem
SELECT system_name, MIN(release_date), MAX(release_date)
FROM versioninfo_extended
GROUP BY system_name;
-- "CARGO"	"2014-11-11 02:22:07"	"2024-01-16 02:50:07"
-- "NPM"	"2010-11-09 23:36:08"	"2023-07-07 04:57:42"
-- "PYPI"	"2005-03-22 22:19:10"	"2023-07-07 12:03:45"

-- checking number of package version releases in each year in each ecosystem.
SELECT system_name, EXTRACT(YEAR FROM release_date) AS YEAR_, COUNT(*)
FROM versioninfo_extended
GROUP BY system_name, YEAR_;
--ORDER BY YEAR_ ASC;



-- checking AVG number of direct dependencies each package has among different versions

-- checking total number of dependencies of each version of each package has
SELECT system_name, from_package_name, from_version, COUNT(DISTINCT to_package_name)
FROM relationssmall
GROUP BY systemname, frompackagename, fromversion;




-- for next subquery: when the first version of each packgae was released
SELECT system_name, package_name, MIN(release_date)
FROM versioninfo_extended
GROUP BY system_name, package_name;

-- checking number of new package released in each year in each ecosystem.
SELECT sub.system_name, EXTRACT(YEAR FROM sub.first_version_release_date) AS YEAR_, COUNT(*)
FROM (
	SELECT system_name, package_name, MIN(release_date) AS first_version_release_date
	FROM versioninfo_extended
	GROUP BY system_name, package_name
) AS sub
GROUP BY sub.system_name, YEAR_;
--ORDER BY YEAR_ ASC;
-- exported to csv and the paper


SELECT ttt.system_name, COUNT(*)
FROM
(
	SELECT DISTINCT system_name, from_package_name, to_package_name
	FROM relations
) as ttt
GROUP BY ttt.system_name;





SELECT ttt.system_name, COUNT(*)
FROM
(
	SELECT DISTINCT system_name, from_package_name
	FROM relations
) as ttt
GROUP BY ttt.system_name;
--  system_name |  count  
-- -------------+---------
--  CARGO       |  122069
--  NPM         | 2603314
--  PYPI        |  274720

SELECT ttt.system_name, COUNT(*)
FROM
(
	SELECT DISTINCT system_name, from_package_name
	FROM relations_minified
) as ttt
GROUP BY ttt.system_name;
--  system_name | count  
-- -------------+--------
--  CARGO       |  15321
--  NPM         | 141551
--  PYPI        |  44199