Running discourse in dev mode using [fig](http://www.fig.sh/)

This is an alternative to [using Vagrant](VAGRANT.md). It will run discourse, postgres, redis, and nginx on the local host in separate docker containers. This more closely approximates production configurations where you use external database and redis. Nginx is used to serve static assets.

This configuration uses a different discourse docker image than the one described in [INSTALL](INSTALL.md). This image is built from the [Dockerfile in this repository](../Dockerfile); it does not include postgres, redis, or nginx; and it's build from a standard base image.

The fig configuration is in fog.yml which you should modify to your needs.

If you are running on linux, the server will listen on http://localhost. If you are on mac using boot2docker, you can find the server's ip address by doing `boot2docker ip`. You can access the rails application directly (bypassing nginx) by using port 3000 instead of 80.

1. [Install fig](http://www.fig.sh/install.html) (this requires you to install docker and, on Mac, VirtualBox).
2. Check `fig.yml`, you may need to edit it to suit your needs.
3. `fig build`
4. `fig run discourse bundle exec rake db:create db:migrate db:seed_fu`
5. `fig up`
6. The server should be up.


This can also be used to run the test suite:

1. `fig build` if you haven't done it
2. `fig run discourse bash -c 'RAILS_ENV=test bundle exec rake db:drop db:create db:migrate'` to create and prepare the test database
3. `fig run discourse bash -c 'bundle exec rake autospec p l=5'`

Similarly, you can use this to run other rails tools, e.g.,

1. rails console: `fig run discourse bundle exec rails console`
2. update gems: `fig run discourse bundle install`

You can edit the source code as usual and it will be reflected in the running server (no need to rebuild, restart, or attach to the docker container).
