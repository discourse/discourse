# Developing using Docker

Since Discourse runs in Docker, why not develop there?  If you have Docker installed, you should be able to run Discourse directly from your source directory using a Discourse development container.

## Step-by-step

It should be as easy as (from your source root):

```sh
./bin/docker/boot_dev --init
    # wait while:
    #   - dependencies are installed,
    #   - the database is migrated, and
    #   - an admin user is created (you'll need to interact with this)

./bin/docker/rails s
```

... then open a browser on http://localhost:3000 and _voila!_, you should see Discourse.

When you're done, you can kill the Docker container with:

```sh
./bin/docker/shutdown_dev
```

Note that data is persisted between invocations of the container in your source root `tmp/postgres` directory.

If for any reason you want to reset your database run

```sh
sudo rm -fr tmp/postgres
```

## Other Notes

##### Where is the container image/Dockerfile defined?

The Dockerfile comes from [discourse/discourse_docker on GitHub](https://github.com/discourse/discourse_docker), in particular [image/discourse_dev](https://github.com/discourse/discourse_docker/tree/master/image/discourse_dev).
