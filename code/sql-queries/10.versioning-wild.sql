ALTER TABLE relations_minified DROP COLUMN IF EXISTS requirement_type;


-- Adding a new column to the relations_minified table
-- to store the constraint type
ALTER TABLE relations_minified
ADD COLUMN requirement_type TEXT;

UPDATE relations_minified
SET requirement_type = CASE
    WHEN actual_requirement IS NULL THEN 'other'
    WHEN get_spec_type(actual_requirement) = 'pinned' THEN 'pinned'
    WHEN get_spec_type(actual_requirement) = 'floating - major' THEN 'floating - major'
    WHEN get_spec_type(actual_requirement) = 'floating - major - restrictive' THEN 'floating - major - restrictive'
    WHEN get_spec_type(actual_requirement) = 'floating - minor' THEN 'floating - minor'
    WHEN get_spec_type(actual_requirement) = 'floating - patch' THEN 'floating - patch'
    ELSE 'other'
END;

UPDATE relations_minified
SET requirement_type = 'null'
WHERE actual_requirement IS NULL
    AND is_regular = true;
-- UPDATE 8000645

CREATE INDEX relations_minified_index_4
ON relations_minified (requirement_type);


-- group by system_name, from_package_name, from_version, to_package_name
-- and from each group take the first row to get the requirement_type
-- and count the types of requirements used overall
WITH FirstRequirementInGroup AS (
    SELECT
        system_name,
        requirement_type,
        -- Use ROW_NUMBER to pick one requirement type per unique dependency relation
        ROW_NUMBER() OVER(PARTITION BY system_name, from_package_name, from_version, to_package_name ORDER BY (SELECT NULL)) as rn
    FROM relations_minified
    WHERE is_regular = TRUE
        AND actual_requirement IS NOT NULL
)
SELECT
    system_name,
    requirement_type,
    COUNT(*) AS usage_count
FROM FirstRequirementInGroup
WHERE rn = 1 -- Filter to get only one row per group
GROUP BY system_name, requirement_type
ORDER BY system_name;
-- system_name |        requirement_type        | usage_count 
-- -------------+--------------------------------+-------------
--  CARGO       | floating - major               |         106
--  CARGO       | floating - major - restrictive |          98
--  CARGO       | floating - minor               |       99970
--  CARGO       | floating - patch               |        1335
--  CARGO       | other                          |        3182
--  CARGO       | pinned                         |         126
--  NPM         | floating - major               |      389961
--  NPM         | floating - major - restrictive |        1944
--  NPM         | floating - minor               |    34148963
--  NPM         | floating - patch               |     1094980
--  NPM         | other                          |       84392
--  NPM         | pinned                         |    15380765
--  PYPI        | floating - major               |     1465062
--  PYPI        | floating - major - restrictive |       56926
--  PYPI        | floating - minor               |      919946
--  PYPI        | floating - patch               |      431793
--  PYPI        | other                          |     1496250
--  PYPI        | pinned                         |        2867
-- (18 rows)



-- updated RQ1 results
WITH categorized_requirements AS (
    SELECT 
        system_name,
        from_package_name,
        from_version,
        to_package_name,
        requirement_type,
        interval_start,
        interval_end
    FROM 
        relations_minified
    WHERE 
        is_regular = true
        AND actual_requirement IS NOT NULL
)
SELECT 
    system_name,
    requirement_type,
    COUNT(*) as total_count,
    COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name, from_version, to_package_name)) as unique_pkg_pkgver_dep_count,
    COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name, to_package_name)) as unique_pkg_dep_count,
    COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name)) as unique_pkg_count
FROM 
    categorized_requirements
GROUP BY 
    system_name, requirement_type
ORDER BY
    system_name, requirement_type;

--  system_name |  requirement_type  | total_count | unique_pkg_pkgver_dep_count | unique_pkg_dep_count | unique_pkg_count 
-- -------------+--------------------+-------------+-----------------------------+----------------------+------------------
--  CARGO       | at-most            |           2 |                           1 |                    1 |                1
--  CARGO       | complex-expression |           6 |                           3 |                    3 |                3
--  CARGO       | fixed-ranging      |         909 |                         535 |                  176 |              125
--  CARGO       | floating-major     |         221 |                         113 |                   18 |               18
--  CARGO       | floating-minor     |      188849 |                       99877 |                 6674 |             3268
--  CARGO       | floating-patch     |        2622 |                        1302 |                  173 |              111
--  CARGO       | pinning            |        5094 |                        2986 |                  192 |              141
--  NPM         | at-most            |        6277 |                        3534 |                  187 |              136
--  NPM         | complex-expression |         870 |                         626 |                   29 |               19
--  NPM         | fixed-ranging      |      115725 |                       75018 |                 1383 |              795
--  NPM         | floating-major     |     1803206 |                      402644 |                18757 |            10220
--  NPM         | floating-minor     |    52556810 |                    34092953 |               614392 |           105826
--  NPM         | floating-patch     |     1846202 |                     1100620 |                28500 |             9533
--  NPM         | or-expression      |       86235 |                       40702 |                 1859 |             1225
--  NPM         | pinning            |    22557885 |                    15384917 |               180851 |            41216
--  PYPI        | at-most            |      137611 |                       74123 |                 5523 |             3291
--  PYPI        | complex-expression |      106270 |                       49113 |                 3551 |             1773
--  PYPI        | fixed-ranging      |     2644754 |                     1265353 |                48638 |            12823
--  PYPI        | floating-major     |     3268177 |                     1453788 |                76232 |            22087
--  PYPI        | floating-minor     |       10583 |                        5749 |                  487 |              249
--  PYPI        | floating-patch     |      444148 |                      237391 |                11551 |             3375
--  PYPI        | not-expression     |        9104 |                        3449 |                  296 |              246
--  PYPI        | pinning            |     2240412 |                     1286540 |                47036 |             9016
-- (23 rows)





WITH dependency_stats AS (
    SELECT 
        system_name,
        from_package_name,
        from_version,
        to_package_name
    FROM 
        relations_minified
    WHERE 
        is_regular = true
        AND actual_requirement IS NOT NULL
)
SELECT 
    system_name,
    COUNT(*) as total_count,
    -- Count unique package version dependencies
    COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name, from_version, to_package_name)) as unique_pkg_version_deps,
    -- Count unique package dependencies (ignoring versions)
    COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name, to_package_name)) as unique_pkg_deps,
    -- Count unique packages
    COUNT(DISTINCT from_package_name) as unique_packages,
    -- Calculate average dependencies per package
    ROUND(COUNT(DISTINCT CONCAT_WS('|', system_name, from_package_name, to_package_name))::numeric / 
          NULLIF(COUNT(DISTINCT from_package_name), 0)::numeric, 2) as avg_deps_per_package
FROM 
    dependency_stats
GROUP BY 
    system_name
ORDER BY
    total_count DESC;

--  system_name | total_count | unique_pkg_version_deps | unique_pkg_deps | unique_packages | avg_deps_per_package 
-- -------------+-------------+-------------------------+-----------------+-----------------+----------------------
--  NPM         |    78973210 |                51101005 |          741250 |          118035 |                 6.28
--  PYPI        |     8861059 |                 4372844 |          155574 |           31135 |                 5.00
--  CARGO       |      197703 |                  104817 |            6854 |            3323 |                 2.06
-- (3 rows)