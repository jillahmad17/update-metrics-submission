-- 1. create a small table "relationssmall" containing the first 100 rows from the BIG relations table (show relationssmall table)
CREATE TABLE relationssmall AS
SELECT *
FROM relations
LIMIT 100;

SELECT * FROM relationssmall;

-- (working) but not necessary right now
CREATE TABLE relationsbig AS
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days
FROM relations R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY frompackagereleasedate;

-- (properly working) 2. Join "relationssmall" with versioninfo to get the release dates and get the TTU value from subtracting them
-- with appropriate group by and order by
-- problem: one package can have multiple versions of the same package in its dependency
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;

-- testing one
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days,
R1.systemname AND LAG(systemname, 1, 0) OVER(ORDER BY )
AND R1.frompackagenam=frompackagename AND R1.fromversion!=fromversion AND R1.topackagename=topackagename)
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;


-- (working) 3. checking which <frompackage, fromversion> has multiple versions of the same dependency
-- interesting finding: zyz has no dependencies in deps.dev, zzgui has only the highest version of qscintilla
SELECT R1.systemname, R1.frompackagename, R1.fromversion, R1.topackagename, COUNT(*) AS _count
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, R1.topackagename
HAVING COUNT(*) > 1;

-- (working) 4. create a table of <frompackagename, fromversion, topackagename> records for exclusion later
CREATE TABLE excluderecordssmall AS
SELECT R2.systemname AS newsystemname, R2.frompackagename AS newfrompackagename, R2.fromversion AS newfromversion, R2.topackagename AS newtopackagename, COUNT(*) AS _count
FROM relationssmall R2
INNER JOIN versioninfo V3
ON R2.frompackagename = V3.packagename AND R2.fromversion = V3.versionname
INNER JOIN versioninfo V4
ON R2.topackagename = V4.packagename AND R2.toversion = V4.versionname
GROUP BY R2.systemname, R2.frompackagename, R2.fromversion, R2.topackagename
HAVING COUNT(*) > 1;

-- (working but not necessary)
-- getting all the records where <frompackage, fromversion> has MULTIPLE versions of the same dependency
-- 45 records
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days
FROM relationssmall R1
INNER JOIN (
	SELECT R2.systemname AS newsystemname, R2.frompackagename AS newfrompackagename, R2.fromversion AS newfromversion, R2.topackagename AS newtopackagename, COUNT(*) AS _count
	FROM relationssmall R2
	INNER JOIN versioninfo V3
	ON R2.frompackagename = V3.packagename AND R2.fromversion = V3.versionname
	INNER JOIN versioninfo V4
	ON R2.topackagename = V4.packagename AND R2.toversion = V4.versionname
	GROUP BY R2.systemname, R2.frompackagename, R2.fromversion, R2.topackagename
	HAVING COUNT(*) > 1
) new_table
ON new_table.newsystemname = R1.systemname AND new_table.newfrompackagename = R1.frompackagename AND new_table.newfromversion = R1.fromversion AND new_table.newtopackagename = R1.topackagename
-- now it should give us only the duplicates
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;



-- (working) 5. getting all the records where <frompackage, fromversion> has only one version of the same dependency
-- 55 records
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
WHERE NOT EXISTS (
	SELECT *
	FROM excluderecordssmall E1
	WHERE E1.newsystemname = R1.systemname AND E1.newfrompackagename = R1.frompackagename AND E1.newfromversion = R1.fromversion AND E1.newtopackagename = R1.topackagename
)
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;


-- (working) create a temp table with the above working qeury
-- 6. saving the above query in a table
CREATE TABLE temptable AS
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
WHERE NOT EXISTS (
	SELECT *
	FROM excluderecordssmall E1
	WHERE E1.newsystemname = R1.systemname AND E1.newfrompackagename = R1.frompackagename AND E1.newfromversion = R1.fromversion AND E1.newtopackagename = R1.topackagename
)
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;


-- (testing) populate the appropriate column
SELECT *,
CASE
	WHEN systemname = LAG(T1.systemname, 1) OVER(
		PARTITION BY T1.systemname, T1.frompackagename, T1.topackagename
		ORDER BY T1.systemname, T1.frompackagename, T1.topackagename, T1.frompackagereleasedate--should be ok to keep time here only
	) THEN 1
	ELSE 0
END AS systemnamesame
FROM temptable T1;

SELECT * FROM temptable;


-- (working looks like) figure out the rows having meaningful ttu values
SELECT R1.systemname, R1.frompackagename, R1.fromversion, V1.releasedate AS frompackagereleasedate, R1.topackagename, R1.toversion, V2.releasedate AS toreleasedate, V1.releasedate - V2.releasedate AS ttu, EXTRACT(days FROM V1.releasedate - V2.releasedate) AS ttu_in_days,
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
		R1.fromversion != LAG(R1.fromversion, 1) OVER (
			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
		) AND 
-- 		R1.topackagename = LAG(R1.topackagename, 1) OVER (
-- 			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
-- 			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
-- 		) AND 
		R1.toversion != LAG(R1.toversion, 1) OVER (
			PARTITION BY R1.systemname, R1.frompackagename, R1.topackagename--, R1.toversion, toreleasedate
			ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, V1.releasedate
		)
		THEN 1
	ELSE NULL -- first row in the GROUP
	-- WHEN LAG(ttu_in_days, 1, 0) OVER (ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate)
END AS is_appropriate
FROM relationssmall R1
INNER JOIN versioninfo V1
ON R1.frompackagename = V1.packagename AND R1.fromversion = V1.versionname
INNER JOIN versioninfo V2
ON R1.topackagename = V2.packagename AND R1.toversion = V2.versionname
WHERE NOT EXISTS (
	SELECT *
	FROM excluderecordssmall E1
	WHERE E1.newsystemname = R1.systemname AND E1.newfrompackagename = R1.frompackagename AND E1.newfromversion = R1.fromversion AND E1.newtopackagename = R1.topackagename
)
GROUP BY R1.systemname, R1.frompackagename, R1.fromversion, frompackagereleasedate, R1.topackagename, R1.toversion, toreleasedate
ORDER BY R1.systemname, R1.frompackagename, R1.topackagename, frompackagereleasedate;


