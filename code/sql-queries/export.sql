COPY time_out_of_date_combined TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/time_out_of_date_combined.csv' DELIMITER ',' CSV HEADER;
COPY time_out_of_date_combined_maintained TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/time_out_of_date_combined_maintained.csv' DELIMITER ',' CSV HEADER;
COPY tofd_vs_versions TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_vs_versions.csv' DELIMITER ',' CSV HEADER;
COPY tofd_vs_major_versions TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_vs_major_versions.csv' DELIMITER ',' CSV HEADER;
COPY tofd_vs_dependencies TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_vs_dependencies.csv' DELIMITER ',' CSV HEADER;
COPY tofd_vs_dependents TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_vs_dependents.csv' DELIMITER ',' CSV HEADER;
COPY tofd_vs_age TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_vs_age.csv' DELIMITER ',' CSV HEADER;
COPY tofd_of_critical TO 
'/Users/imranur/Research/security-metrics/data/time-out-of-date-from-db/tofd_of_critical.csv' DELIMITER ',' CSV HEADER;



COPY post_fix_exposure_time_combined TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/post_fix_exposure_time_combined.csv' DELIMITER ',' CSV HEADER;
COPY post_fix_exposure_time_combined_maintained TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/post_fix_exposure_time_combined_maintained.csv' DELIMITER ',' CSV HEADER;
COPY pfet_vs_versions TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_vs_versions.csv' DELIMITER ',' CSV HEADER;
COPY pfet_vs_major_versions TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_vs_major_versions.csv' DELIMITER ',' CSV HEADER;
COPY pfet_vs_dependencies TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_vs_dependencies.csv' DELIMITER ',' CSV HEADER;
COPY pfet_vs_dependents TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_vs_dependents.csv' DELIMITER ',' CSV HEADER;
COPY pfet_vs_age TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_vs_age.csv' DELIMITER ',' CSV HEADER;
COPY pfet_of_critical TO 
'/Users/imranur/Research/security-metrics/data/post-fix-exposure-time-from-db/pfet_of_critical.csv' DELIMITER ',' CSV HEADER;


COPY mean_time_to_update_maintained TO 
'/home/imranur/security-metrics/data/mttu/mttu.csv' DELIMITER ',' CSV HEADER;

COPY mean_time_to_remediate_maintained TO 
'/home/imranur/security-metrics/data/mttr/mttr.csv' DELIMITER ',' CSV HEADER;

`\copy (select * from mean_time_to_update_maintained) to '/home/imranur/security-metrics/data/mttu/mttu.csv' with header delimiter as ','` (count: 163207) and
`\copy (select * from mean_time_to_remediate_maintained) to '/home/imranur/security-metrics/data/mttr/mttr.csv' with header delimiter as ','` (count: 22513)

COPY relations_minified_versioning TO 
'/home/imranur/security-metrics/data/relationships/relations_minified_versioning.csv' DELIMITER ',' CSV HEADER;

`\copy (select dependency_id, dependency_key, interval_start_days, interval_end_days, requirement_type, is_out_of_date, is_exposed from relations_minified_versioning) to '/home/imranur/security-metrics/data/relationships/relations_minified_versioning.csv' with header delimiter as ','` (count: COPY 1559743)