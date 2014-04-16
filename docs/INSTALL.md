# How Do I Install Discourse?

Simple 30 minute install:  
[**Beginner Docker install guide for Digital Ocean**][do]

A more powerful, flexible install:  
[**Advanced Docker install guide**][docker]

The only officially supported installs of Discourse are the [Docker](https://www.docker.io/) based beginner and advanced installs. We regret that we cannot support any other methods of installation. (Alternately, you can try the [unofficial Heroku install guide][heroku], the [unofficial Ubuntu install guide][ubuntu], the [BitNami Discourse Virtual Machine package][bitnami] or [Cloud66][cloud66].)

### Hardware Requirements

- Dual core CPU recommended
- 1 GB RAM minimum (with [swap][swap]), 2 GB recommended

### Software Requirements

- [Postgres 9.1+](http://www.postgresql.org/download/)
- [Redis 2.6+](http://redis.io/download)
- [Ruby 1.9.3+](http://www.ruby-lang.org/en/downloads/) (we recommend 2.0.0-p353 or higher)


[do]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-digital-ocean.md
[docker]: https://github.com/discourse/discourse_docker
[bitnami]: http://bitnami.com/stack/discourse
[cloud66]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud66.md
[heroku]: https://github.com/discourse/discourse/blob/master/docs/install-HEROKU.md
[ubuntu]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md
[swap]: https://www.digitalocean.com/community/articles/how-to-add-swap-on-ubuntu-12-04
