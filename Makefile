.PHONY: init run down bash 

# 
# d/ is a symbolic link to bin/docker 		
#

init:
	# Start a new container based on discourse_dev image:
	# https://github.com/discourse/discourse_docker/tree/master/image/discourse_dev
	# /!\ The Ruby version is taken from the master Discourse repository,
	# not our fork, and we cannot change it as it's hard-coded in the Dockerfile.
	# That is why you may experience errors during the `bundle install` step
	# and later in the application.
	d/boot_dev
	d/bundle install
	# d/migrate	
	# Disable initial migrations to work with the prod database.		

run:
	# Start the Rails server
	d/rails s

down:
	# Stop and remove Discourse container 	
	d/shutdown_dev

bash:
	docker exec -it discourse_dev bash

#####################################
############ Database ###############
.PHONY: db_bash db_grant_privileges db_clean db_restore

#####################################
db_bash:
	docker exec -u postgres -it discourse_dev bash -c "psql -d discourse_development"

db_grant_privileges:
	# The discourse user, used by each Discourse command in their Docker configuration,
	# does not have enough privileges do dump or recreate the database,
	# only the postgres user can do it.
	# Grant privileges to manipulate the DB as we want.
	docker exec -u postgres discourse_dev bash -c "psql discourse_development --command '\
	GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO discourse;\
	GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO discourse;'"

# We need to clean the whole database beforehand because seed is called each db:migrate.
# See /lib/tasks/db.rake
db_clean:
	# /data/postgres is a mounted in the container and used to
	# make data persistent between two runs.
	sudo rm -rf /data/postgres
	make db_grant_privileges
	docker exec -it -u discourse -w /src discourse_dev /bin/bash -c "rake db:truncate_all"

db_restore:
	sudo cp discourse_dump.sql data/postgres/discourse_dump.sql | true

	docker exec -it -u postgres discourse_dev pg_restore -d discourse_development --clean --create  --no-owner --no-privileges --format=c "/shared/postgres_data/discourse_dump.sql"
