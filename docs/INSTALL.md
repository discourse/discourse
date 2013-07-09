# Discourse "Quick-and-Dirty" Install Guide

It is still early times for Discourse. From our FAQ:

> Discourse is brand new. Discourse is early beta software, and likely to remain so for many months.
> Please experiment with it, play with it, give us feedback, submit pull requests – but any consideration
> of fully adopting Discourse is for people and organizations who are eager to live on the bleeding and broken edge.

Discourse has two fairly decent install documents now:

- Our [**official Ubuntu Server 12.04 LTS install document**][1]
- [Unofficial Heroku install document][2]

Beyond that, if you are feeling extra *extra* adventurous you'll need some server hardware:

- Dual core CPU recommended
- 2 GB RAM recommended (1 GB can work, but you'll need swap..)

And you can try to set up following components manually on it:

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
  - Run a clockwork process for enqueing scheduled jobs
  - Run several Rails processes, preferably behind a proxy like Nginx.

---

# Low memory installs

- Clockwork can run inside your web server, if you launch the your web server with EMBED_CLOCKWORK=1, 
   clockwork will run in a backgroud thread. As clockwork itself only performs scheduling, it will have
   very little impact on performance

[1]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md
[2]: https://github.com/discourse/discourse/blob/master/docs/HEROKU.md

