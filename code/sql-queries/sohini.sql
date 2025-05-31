select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'swagger-ui';

select *
from versioninfo_extended
where package_name = 'swagger-ui';

select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'dojo';

select *
from versioninfo_extended
where system_name = 'NPM' and package_name = 'dojo';

select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'electron';

select *
from versioninfo_extended
where system_name = 'NPM' and package_name = 'electron';

select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'urijs';

select *
from versioninfo_extended
where system_name = 'NPM' and package_name = 'urijs';

select *
from relations_with_all
where system_name = 'NPM' and to_package_name = 'protobufjs';

select *
from versioninfo_extended
where system_name = 'NPM' and package_name = 'protobufjs';