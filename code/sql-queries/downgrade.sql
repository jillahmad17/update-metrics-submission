-- (working looks like) figure out the rows having meaningful ttu values but having 'downgrade'
CREATE TABLE relation_with_downgrade AS
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
END AS is_appropriate,
CASE
	WHEN
		R1.from_version::text != LAG(R1.from_version::text, 1) OVER (
			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
		) AND 
		R1.to_version::text != LAG(R1.to_version::text, 1) OVER (
			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
		) AND
		-- this needs is_appropriate to be true/1 also
		V2.release_date < LAG(V2.release_date, 1) OVER (
			PARTITION BY R1.system_name, R1.from_package_name, R1.to_package_name--, R1.toversion, toreleasedate
			ORDER BY R1.system_name, R1.from_package_name, R1.to_package_name, R1.from_version, R1.to_version
		) 
		THEN 1
	ELSE NULL
END AS is_downgrade
FROM 
(
	SELECT *, 
			ROW_NUMBER() OVER(PARTITION BY R2.system_name, 
									 R2.from_package_name, 
									 R2.from_version,
									 R2.to_package_name
			ORDER BY R2.to_version DESC) row_num
	FROM relations R2
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
-- took 1 hr 29 min


SELECT COUNT(*)
FROM relation_with_downgrade
WHERE is_downgrade=1;