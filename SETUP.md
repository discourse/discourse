## Setup

This is a guide on how to setup and run the Karota webapp in a local machine using Docker.

### Prerequisute

1. Installed Docker in your local machine.

## First time setup
  
Run this command in the terminal in the root directory, this will install the dependencies, migrate the database, and will create an admin user which need an interaction.

```
$ d/boot_dev --init
```

To know that the initial setup is successful, the user will be asked to create an admin user. By the end of initial setup, the user will have an admin account
and the first user of the Karota webapp.

## Run the container

1. Assuming that the Docker container is not yet running, the Docker image name is 'discourse/discourse_dev:release' --> we will change this in the future. Run this command run this command to start the container:

```
$ d/boot_dev
```

2. Next step is to run the service for the backend of the webapp, run this command in the terminal:

```
$ d/rails s
```

3. Last step is to run the service for the frontend of the webapp, run this command in the terminal:

```
$ d/ember-cli
```

You can access the webapp on the browser on `localhost:4200`.


## Troubleshooting

1. The initial setup failed at the the 'database migration stage'
	This error occured because of a missing node package, to resolve this, run this command:

	```
	$ d/ember-cli
	```

## Creating users

The easiest way to create a new user is by using the 'signup' functionality of the webapp. The webapp is supposed to send an activation email but it's not working, I think because the webapp is running on localhost. So the alternative to activate a newly created account is by using the admin functionality of the webapp. Follow the steps below to activate a newly registered account:

1. Assuming that the admin user is logged in, click the 'hamburger nav icon' beside the user's avatar.
2. Click the '&#128295; Admin' button
3. You will be redirected to `/admin` url, there will be a mini navigation bar, click the 'Users' and you will see all the current users of the webapp.
4. Click the username of the newly registered user that is not yet activated, the color of the username will be gray so it's noticable.
5. You will be redirected to the information of the user, scroll down and there's 'Permissions' section, the first item of this section is 'Activated', just click the 'Activate account' button and the user can now login without the activation email notice.

## Reference

https://meta.discourse.org/t/beginners-guide-to-install-discourse-for-development-using-docker/