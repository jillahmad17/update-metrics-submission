WITH
cte
AS
(
SELECT ctid,
       row_number() OVER (PARTITION BY system_name,
                                       	from_package_name,
				from_version,
				to_package_name,
				actual_requirement,
				to_version,
				to_package_highest_available_release,
				interval_start,
				interval_end,
				is_out_of_date,
				is_regular
                          ORDER BY system_name,
                                       	from_package_name,
				from_version,
				to_package_name,
				actual_requirement,
				to_version,
				to_package_highest_available_release) rn
       FROM relations
)
DELETE FROM relations
       USING cte
       WHERE cte.rn > 1
             AND cte.ctid = relations.ctid;
