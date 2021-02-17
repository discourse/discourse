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
	d/reset_db
	d/bundle install
	docker exec -u postgres discourse_dev bash -c "psql --command '\
		ALTER USER discourse CREATEDB;\
		ALTER ROLE discourse SUPERUSER'"
	docker exec -it -u discourse -w /src discourse_dev /bin/bash -c "rake db:create"
	# d/migrate
	# Disable initial migrations to work with the prod database.
	# Careful with d/migrate: seed is called each db:migrate.
	# See /lib/tasks/db.rake

run:
	# Start the Rails server
	d/rails s

rails_console:
	docker exec -it -u discourse -w /src discourse_dev /bin/bash -c "rails console"

down:
	# Stop and remove Discourse container
	d/shutdown_dev

bash:
	docker exec -it discourse_dev bash

update_discourse:
	git fetch upstream
	git merge upstream/master

#####################################
############ Database ###############
#####################################
.PHONY: db_bash db_grant_privileges db_truncate db_drop db_restore

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

db_truncate:
	# /data/postgres is a mounted in the container and used
	# to make data persistent between two runs.
	sudo rm -rf /data/postgres
	make db_grant_privileges
	docker exec -it -u discourse -w /src discourse_dev /bin/bash -c "rake db:truncate_all"

db_drop:
	docker exec -it -u postgres discourse_dev dropdb discourse_development

# Make sure the database is empty!
# You should run `make init` just before.
db_restore:
	sudo cp discourse_dump.sql data/postgres/discourse_dump.sql | true

	# Restore the database transferring the table ownership to the discourse user.
	docker exec -it -u postgres discourse_dev pg_restore -d discourse_development --no-owner --role=discourse --no-privileges --format=c "/shared/postgres_data/discourse_dump.sql"

	###> If you upgraded Discourse, make sure you run `d/migrate`!

	###> You should also change site settings:
	# `make db_bash`
	# and then:
	# ```
	# UPDATE site_settings
	# SET value = concat(value, '|localhost:3000')
	# WHERE name='content_security_policy_script_src';

	# UPDATE site_settings
	# SET value = false
	# WHERE name='force_https';
	# ```

	###> For staging:
	# UPDATE site_settings
	# SET value = 'https://staging.forum.inclusion.beta.gouv.fr'
	# WHERE name='vapid_base_url';

##############################
########## Components ########
##############################
# make new_component GITURL=git@github.com:betagouv/discourse-component-hotjar.git REPONAME=discourse-component-hotjar
.ONESHELL:
new_component:
	# Initialize an empty repo on Github and choose a LICENCE first.
	git clone $(GITURL)
	cd $(REPONAME)
	touch about.json
	cat > about.json <<-EOF
	{
		"name": "My component",
		"about_url": "about-url",
		"license_url": "https://github.com/discourse/discourse-matomo-analytics/blob/master/LICENSE",
		"component": true
	}
	EOF

	touch settings.yml

	cat > settings.yml <<-EOF
	host_url:
			type: string
			default: ''
			description: Host URL without http:// or https://
	EOF

	mkdir common
	#   mkdir desktop
	#   mkdir mobile
	touch common/common.scss
	touch common/head_tag.html
	touch common/header.html
	touch common/after_header.html
	touch common/body_tag.html
	touch common/footer.html
	touch common/embedded.scss

	cd .. && mv $(REPONAME) ..
