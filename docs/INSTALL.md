# How Do I Install Discourse?

Simple 30 minute basic install:
[**Beginner Docker install guide**][basic]

Powerful, flexible, large or multiple server install:
[**Advanced Docker install guide**][advanced]

The only officially supported installs of Discourse are the [Docker](https://www.docker.io/) based beginner and advanced installs. We regret that we cannot support any other methods of installation.

### Why do you only officially support Docker?

Hosting Rails applications is complicated. Even if you already have Postgres, Redis and Ruby installed on your server, you still need to worry about running and monitoring your Sidekiq and Rails processes. Additionally, our Docker install comes bundled with a web-based GUI that makes upgrading to new versions of Discourse as easy as clicking a button.

### Hardware Requirements

- Dual core CPU recommended
- 1 GB RAM minimum (with [swap][swap])
- 64 bit Linux compatible with Docker

### Software Requirements

- [Postgres 9.3+](http://www.postgresql.org/download/)
- [Redis 2.6+](http://redis.io/download)
- [Ruby 2.0+](http://www.ruby-lang.org/en/downloads/) (we recommend 2.0.0-p353 or higher)

## Security

We take security very seriously at Discourse, and all our code is 100% open source and peer reviewed. Please read [our security guide](https://github.com/discourse/discourse/blob/master/docs/SECURITY.md) for an overview of security measures in Discourse.

[basic]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md
[advanced]: https://github.com/discourse/discourse_docker
[swap]: https://meta.discourse.org/t/create-a-swapfile-for-your-linux-server/13880
