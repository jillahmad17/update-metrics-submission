# Data Collection from OVS

Use this [url](https://google.github.io/osv.dev/data/#data-dumps) to download all the data for different ecosystem from osv.dev site. [Data collected on Sep 12, 2024]

# Methodology
1. Use the OSV dataset to find the package name with the version infos when the vulnerability was introduced and when the vulnerability was fixed.
2. Query the deps.dev to find out what packages are direct dependent of this vulnerable package (and of this specific version).
3. From the dependent's list find out how much time was needed for each of the dependent to update this package from vulnerable to fixed version.

# Data shared from Google
1. Install Semver extension for Postgres [url](https://pgxn.org/dist/semver/). This [url](https://stackoverflow.com/questions/56724622/how-to-fix-postgres-h-file-not-found-problem) might be helpful.
2. Insert data from csv to database using Jupyter notebook.
3. Alter table column type to Semver.
4. JOIN, AGGREGATE etc to find out the proper TTU values.

# Steps
1. Run 'relations populate in POSTGRES' from the Jupyter Notebook.
2. 

# PDF conversion to high-resolution PNG
`pdftoppm -png -r 1200 ttu.pdf ttu`

# Restart postgres server ([url](https://stackoverflow.com/a/76626198/3450691))
1. `sudo -i -u postgres`
2. `/Library/PostgreSQL/15/bin/pg_ctl -D /Library/PostgreSQL/15/data restart`


# Steps from the beginning

System tested: ubuntu 24.04

- Create a python virtual environment (`python3 -m venv venv`), activate it (`source venv/bin/activate`), and install the required libraries (`pip3 install -r requirements.txt`).
- Install the [google-cloud-sdk](https://cloud.google.com/sdk/docs/install#deb) (for Mac: `brew install --cask google-cloud-sdk`) and create a new project in Google Cloud Console before downloading the package version data from deps.dev.
    - [Set up everything](https://cloud.google.com/docs/authentication/provide-credentials-adc#how-to) using `gcloud init` and `gcloud auth application-default login`.
    - Grant your user the permission to run Google BigQuery jobs. Go to this [url](https://console.cloud.google.com/iam-admin/iam?authuser=1&cloudshell=true&organizationId=0&project=bigquery-parser), create new permission by clicking `grant access` and set your email address and `roles/bigquery.jobUser` role.
    - (Optional) If you are facing error like "403 Quote Exceeded" that means you have used the free quota for your account already. In that case, you need to revoke your account credentials `gcloud auth revoke --all` and your ADC credentials `gcloud auth application-default revoke`, and do the above steps again with a different gmail account.
    - (Optional) If the previous step does not eliminate the "403 Quote Exceeded", you may need to uninstall the `google-cloud-sdk` and reinstall it again ([ref url](https://cloud.google.com/sdk/docs/uninstall-cloud-sdk)).
    - (Optional) If you still face this error, go to the [quota troubleshoot page](https://cloud.google.com/bigquery/docs/troubleshoot-quotas) and navigate to the "Log Explorer" page to see where the error is coming from. If it has something to do with "no billing account found", you may have to add a billing account to use the query.
- Install `postgresql` in the machine using `sudo apt install postgresql`
    - Set the default password for *postgres* user by `sudo -u postgres psql template1`, `ALTER USER postgres with encrypted password 'your_password';`, and `sudo systemctl restart postgresql.service`.
    - Login to psql terminal using `sudo -i -u postgres` and `psql`.
    - Create a new database *metrics* `create database metrics;`
    - (Optional) Delete existing user if already exists `DROP USER IF EXISTS metricsuser;`
    - (Optional) `\du` to see all the available users and their roles.
    - (Optional) If one needs to delete a table `DROP TABLE IF EXISTS relations;`
    - Create a new user *metricsuser* `CREATE USER metricsuser WITH PASSWORD 'metricspassword';`
    - Grant all permissions to *metricsuser* `GRANT ALL PRIVILEGES ON DATABASE "metrics" to metricsuser;`
    - (Optional) Login to psql with this *metricsuser* by `psql -h localhost -d metrics -U metricsuser -p 5432` and it will prompt for password.
    - (Optional) `\z` to see all the schema and tables.
    - (Optional) `\d+ relations` to see the data types of *relations* table.
    - (Optional) `\di` to see the created indexes for the current schema.
    - Change the owner of the *metrics* database to user *metricsuser* using `alter database metrics owner to metricsuser;` since there are some changes from PostgreSQL 15 ([link](https://stackoverflow.com/a/77289725/3450691)).
    - Give the user superuser permission by `ALTER USER metricsuser with SUPERUSER;`.
    - `\q` to quit from psql terminal.


# error.txt
```Query canceled: COPY from stdin failed: error in .read() call: UnicodeEncodeError 'ascii' codec can't encode character '\xa0' in position 7123: ordinal not in range(128)
CONTEXT:  COPY relations, line 166803
```

- Download the osv datasets ([Reference](https://google.github.io/osv.dev/data/#data-dumps))
    - `gsutil cp gs://osv-vulnerabilities/PyPI/all.zip data/osv-data/pypi.zip` and unzip `unzip ./data/osv-data/pypi.zip -d ./data/osv-data/pypi`
    - `gsutil cp gs://osv-vulnerabilities/npm/all.zip data/osv-data/npm.zip` and unzip `unzip ./data/osv-data/npm.zip -d ./data/osv-data/npm`
    - `gsutil cp gs://osv-vulnerabilities/crates.io/all.zip data/osv-data/crates.io.zip` and unzip `unzip ./data/osv-data/crates.io.zip -d ./data/osv-data/crates.io`
- Build the osv table by running `code/build-db-from-osv/build-db-from-osv.ipynb`
- Build the relations table and versioninfo table by running `code/build-db/build_db.ipynb`
- Remove duplicates in relations table by running `1.remove_duplicates.sql`
- Install the semver extension from [here](https://github.com/theory/pg-semver.git).
    - `sudo apt install make gcc postgresql-server-dev-16`
    - Follow the instructions in the repo to install it.
    - If you have issues installing the extension for a new use see this [url](https://stackoverflow.com/a/63554796/3450691) or this [url](https://stackoverflow.com/a/43937189/3450691).
- Run `3.osv.sql`.
- At this stage the current status of tables:
```
List of relations
 Schema |         Name         | Type  |    Owner    | Persistence | Access method |  Size   | Description 
--------+----------------------+-------+-------------+-------------+---------------+---------+-------------
 public | osv                  | table | metricsuser | permanent   | heap          | 1536 kB | 
 public | osv_extended         | table | metricsuser | permanent   | heap          | 1544 kB | 
 public | relations            | table | metricsuser | permanent   | heap          | 491 GB  | 
 public | relations_minified   | table | metricsuser | permanent   | heap          | 101 GB  | 
 public | versioninfo          | table | metricsuser | permanent   | heap          | 3823 MB | 
 public | versioninfo_extended | table | metricsuser | permanent   | heap          | 4828 MB | 
```
- Run `4.time_to_update.sql` and `5.time_to_remediate.sql`.
- Export the tables using `\copy (select * from mean_time_to_update_maintained) to '/home/imranur/security-metrics/data/mttu/mttu.csv' with header delimiter as ','` (count: 163207) and `\copy (select * from mean_time_to_remediate_maintained) to '/home/imranur/security-metrics/data/mttr/mttr.csv' with header delimiter as ','` (count: 22513).
- Result should be in the `/results/` directory structured into subdirectories.