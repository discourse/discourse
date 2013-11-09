# How Do I Install Discourse?

It is still early times for Discourse. From [our FAQ](http://www.discourse.org/faq/):

> Discourse is brand new. Discourse is early beta software, and likely to remain so for many months.
> Please experiment with it, play with it, give us feedback, submit pull requests – but any consideration
> of fully adopting Discourse is for people and organizations who are eager to live on the bleeding and broken edge.

Still interested?

### [**Click here for the OFFICIAL INSTALL GUIDE**][1]

Alternately, you can try the [unofficial Heroku install guide][2], the [BitNami Discourse Virtual Machine package][3] or [Cloud66][4].

## Quick and Dirty Install

### Hardware

- Dual core CPU recommended
- 2 GB RAM recommended (and 2 GB of swap space)

### Software

1. **Postgres 9.1+**
 - Enable support for HSTORE
 - Create a discourse database and seed it with a basic image

2. **Redis 2.6+**

3. **Ruby 1.9.3+** (we recommend 2.0.0-p195 or higher)
  - Install all rubygems via bundler
  - Edit database.yml and redis.yml and point them at your databases.
  - Run `rake db:seed_fu` to add seed data
  - Prepackage all assets using rake
  - Run the Rails database migrations
  - Run a sidekiq process for background jobs
  - Run several Rails processes, preferably behind a proxy like Nginx.

### Low memory (less than 2 GB)

Remember you *will* need swap enabled (enough for a total of 4 GB, so 2 GB swap with 2 GB RAM, and 3 GB swap with 1 GB ram, etc) and working!

[1]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md
[2]: https://github.com/discourse/discourse/blob/master/docs/HEROKU.md
[3]: http://bitnami.com/stack/discourse
[4]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-cloud66.md
