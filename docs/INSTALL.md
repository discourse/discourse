# How Do I Install Discourse?

> :bell: The only officially supported installs of Discourse are [Docker](https://www.docker.io/) based. You must have SSH access to a 64-bit Linux server **with Docker support**. We regret that we cannot support any other methods of installation including cpanel, plesk, webmin, etc.

Simple 30 minute basic install:  
[**Beginner Docker install guide**][basic]

Powerful, flexible, large / multiple server install:  
[**Advanced Docker install guide**][advanced]

### Why do you only officially support Docker?

Hosting Rails applications is complicated. Even if you already have Postgres, Redis and Ruby installed on your server, you still need to worry about running and monitoring your Sidekiq and Rails processes, as well as configuring Nginx. With Docker, our fully optimized Discourse configuration is available to you in a simple container, along with a web-based GUI that makes upgrading to new versions of Discourse as easy as clicking a button.

### Hardware Requirements

- modern single core CPU, dual core recommended
- 1 GB RAM minimum (with [swap][swap])
- 64 bit Linux compatible with Docker
- 10 GB disk space minimum

### Software Requirements

- [Postgres 10+](https://www.postgresql.org/download/)
- [Redis 2.6+](https://redis.io/download)
- [Ruby 2.5+](https://www.ruby-lang.org/en/downloads/) (we recommend 2.5.2 or higher)

## Security

We take security very seriously at Discourse, and all our code is 100% open source and peer reviewed. Please read [our security guide](https://github.com/discourse/discourse/blob/master/docs/SECURITY.md) for an overview of security measures in Discourse.

[basic]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud.md
[advanced]: https://github.com/discourse/discourse_docker
[swap]: https://meta.discourse.org/t/create-a-swapfile-for-your-linux-server/13880
