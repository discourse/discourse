# How Do I Install Discourse?

If you want the easiest possible install:  
[**Beginner Docker install guide for Digital Ocean**][do]

If you want a powerful, flexible install:  
[**Advanced Docker install guide**][docker]

The only officially supported installs of Discourse are the [Docker](https://www.docker.io/) based beginner and advanced installs, above. We regret that we cannot directly support any other methods of installation.

Alternately, you can try the [unofficial Heroku install guide][heroku], the [unofficial Ubuntu install guide][ubuntu], the [BitNami Discourse Virtual Machine package][bitnami] or [Cloud66][cloud66].

## Requirements

### Hardware

- Dual core CPU recommended
- 2 GB RAM *strongly* recommended
 
We also recommend you [enable swap][swap] for a total of 4 GB, so 2 GB swap with 2 GB RAM, and 3 GB swap with 1 GB ram, etc.

### Software

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
