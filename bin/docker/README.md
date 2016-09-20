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

## Caveats

There seems to be an issue with the ember-data-source gem installed by default (2.3.0.beta.5).  It's missing its `dist` directory.  I've worked around this by acquiring that commit, building the distribution locally, and patching it into `/usr/local/lib/ruby/gems/2.3.0/gems/ember-data-source-2.3.0.beta.5` by hand.  I _believe_ later versions of the gem fix this, but the very next version (2.3.0 proper) bumps the ember-source dependency up to 2.0, which Discourse isn't using yet.

You can get `boot_dev` to patch for you by passing `--patch local/path/to/ember-data-source/dist` on the command-line.  You should only have to do this once (like `--init`).


## Other Notes

##### Where is the container image/Dockerfile defined?

The Dockerfile comes from [discourse/discourse_docker on GitHub](https://github.com/discourse/discourse_docker), in particular [image/discourse_dev](https://github.com/discourse/discourse_docker/tree/master/image/discourse_dev).
