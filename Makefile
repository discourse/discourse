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
	d/boot_dev --init

run:
	# Start the Rails server
	d/rails s

down:
	# Stop and remove Discourse container 	
	d/shutdown_dev

bash:
	docker exec -it discourse_dev bash
