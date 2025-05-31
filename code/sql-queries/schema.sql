DROP TABLE IF EXISTS VersionInfo;

DELETE FROM VersionInfo;

CREATE TABLE VersionInfo (
	SystemName varchar(255) not null,
	PackageName varchar(255) not null,
	Version varchar(255) not null,
	-- ReleaseDate varchar(255) not null
	ReleaseDate timestamptz not null
);

CREATE TABLE Relations(
	SystemName varchar(255) not null,
	FromPackageName varchar(255) not null,
	FromVersion varchar(255) not null,
	ToPackageName varchar(255) not null,
	ToVersion varchar(255) not null
	-- probably have to add some constraints like if 1->2 you cannot add 2->1.
);

SELECT * FROM VersionInfo;

SELECT * FROM Relations;

INSERT INTO VersionInfo(SystemName, PackageName, Version, ReleaseDate)
VALUES('PYPI', 'frida', '10.6.34', '2018-01-19 00:29:03 UTC');