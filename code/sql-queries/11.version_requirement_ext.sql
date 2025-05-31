-- Get the actual requirement in a file for splitting different types of 'other' requirements
\copy (SELECT system_name, actual_requirement FROM relations_minified WHERE actual_requirement IS NOT NULL AND is_regular = true AND requirement_type = 'other') to '/home/imranur/security-metrics/data/dep_status/other.csv' with header delimiter as ',';

-- temporary table for other requirements
CREATE TABLE other_requirements AS
SELECT DISTINCT ON (system_name, to_package_name, actual_requirement) 
    system_name, from_package_name, to_package_name, actual_requirement, requirement_type
FROM relations_minified
WHERE actual_requirement IS NOT NULL 
    AND is_regular = true 
    AND requirement_type = 'other'
ORDER BY system_name, to_package_name, actual_requirement;
-- SELECT 155610

\copy (SELECT * FROM other_requirements) to '/home/imranur/security-metrics/data/dep_status/other.csv' with csv header quote '"' delimiter ',';
\copy (SELECT DISTINCT ON (system_name, to_package_name, actual_requirement) system_name, from_package_name, to_package_name, actual_requirement, requirement_type FROM relations_minified WHERE actual_requirement IS NOT NULL AND is_regular = true ORDER BY system_name, to_package_name, actual_requirement) to '/home/imranur/security-metrics/data/dep_status/all_req.csv' with csv header quote '"' delimiter ',';
-- COPY 3210221