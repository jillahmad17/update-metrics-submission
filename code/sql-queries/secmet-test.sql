DROP TABLE Relations;
DROP TABLE VersionInfo;


SET SQL_SAFE_UPDATES = 0;

# your code SQL here
DELETE FROM Relations;

SET SQL_SAFE_UPDATES = 1;


DELETE FROM Relations;
DELETE FROM VersionInfo;

CREATE TABLE VersionInfo (
	PackageId int not null primary key auto_increment,
	SystemName varchar(255) not null,
	PackageName varchar(255) not null,
	Version varchar(255) not null,
	ReleaseDate varchar(255) not null
);

INSERT INTO VersionInfo(PackageName, Version, ReleaseDate)
VALUES("A", "1.1", "2022-10-10 06:16:00");

INSERT INTO VersionInfo(PackageName, Version, ReleaseDate)
VALUES("B", "3.1", "2020-01-27 23:40:55");

INSERT INTO VersionInfo(PackageName, Version, ReleaseDate)
VALUES("C", "9.5", "2018-04-02 07:24:11");

SELECT * FROM VersionInfo;

SELECT PackageName, Version
From VersionInfo
WHERE PackageName='A';

SELECT *
From VersionInfo
WHERE PackageName='zyz';

-- commit by ticking the blue tick

CREATE TABLE Relations(
	RelationId int not null primary key auto_increment,
    FromPackageId int not null,
    ToPackageId int not null,
    foreign key (FromPackageId) references VersionInfo (PackageId),
    foreign key (ToPackageId) references VersionInfo (PackageId)
    -- probably have to add some constraints like if 1->2 you cannot add 2->1.
);

CREATE TABLE Relations(
	SystemName varchar(255) not null,
	FromPackageName varchar(255) not null,
	FromVersion varchar(255) not null,
	ToPackageName varchar(255) not null,
	ToVersion varchar(255) not null
	-- probably have to add some constraints like if 1->2 you cannot add 2->1.
);

INSERT INTO Relations(SystemName, FromPackageName, FromVersion, ToPackageName, ToVersion)
Values ('ASDF', 'A', '1.0.1', 'B', '3.2.77');

ALTER TABLE relations
ALTER COLUMN from_version TYPE SEMVER
USING CAST((COALESCE(from_version,'0')) AS SEMVER);

ALTER TABLE relations
ALTER COLUMN to_version TYPE SEMVER
USING CAST((COALESCE(to_version,NULL)) AS SEMVER);

INSERT INTO Relations(FromPackageId, ToPackageId)
Values( (SELECT PackageId from VersionInfo WHERE PackageName='A' AND Version='1.1'), 
		(SELECT PackageId from VersionInfo WHERE PackageName='B' AND Version='3.1')
);

INSERT INTO Relations(FromPackageId, ToPackageId)
Values( (SELECT PackageId from VersionInfo WHERE PackageName='A' AND Version='1.1'), 
		(SELECT PackageId from VersionInfo WHERE PackageName='C' AND Version='9.5')
);

SELECT * From Relations;

SELECT V1.PackageName, V1.Version, V2.PackageName, V2.Version
FROM Relations R
INNER JOIN VersionInfo V1 On R.FromPackageId=V1.PackageId
INNER JOIN VersionInfo V2 On R.ToPackageId=V2.PackageId;

SELECT V1.PackageName, V1.Version, V2.PackageName, V2.Version
FROM Relations R
INNER JOIN VersionInfo V1 On R.FromPackageId=V1.PackageId AND V1.PackageName='A'
INNER JOIN VersionInfo V2 On R.ToPackageId=V2.PackageId;

SELECT V1.PackageName, V1.Version, V2.PackageName, V2.Version
FROM Relations R
INNER JOIN VersionInfo V1 On R.FromPackageId=V1.PackageId AND V1.PackageName='A' AND V1.Version='1.1'
INNER JOIN VersionInfo V2 On R.ToPackageId=V2.PackageId;




SELECT *
FROM Relations
WHERE FromPackageName='zyz' OR ToPackageName='zyz';



SELECT count(DISTINCT PackageName)
FROM VersionInfo
WHERE SystemName='NPM';

-- SELECT SystemName, COUNT(DISTINCT PackageName)
-- FROM VersionInfo
-- GROUP BY SystemName;

-- SELECT FromPackageName, FromVersion, ToPackageName, ToVersion
-- FROM Relations
-- WHERE FromPackageName=%s AND ToPackageName=%s;

-- SELECT FromPackageName, FromVersion, ToPackageName, ToVersion
-- FROM Relations
-- WHERE FromPackageName=%s
-- GROUP BY FromVersion;

SELECT FromPackageName, ToPackageName, COUNT(*) AS UniquePairCount
FROM Relations
WHERE FromPackageName='zyz'
GROUP BY FromPackageName, ToPackageName
HAVING COUNT(*) > 1; -- untested yet