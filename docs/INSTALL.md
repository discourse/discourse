# Discourse "Quick-and-Dirty" Install Guide

It is still early times for Discourse. From our FAQ:

> Discourse is brand new. Discourse is early beta software, and likely to remain so for many months.
> Please experiment with it, play with it, give us feedback, submit pull requests – but any consideration
> of fully adopting Discourse is for people and organizations who are eager to live on the bleeding and broken edge.

Discourse has two fairly decent install documents now:

- Our [**official Ubuntu Server 12.04 LTS install document**][1]
- [Unofficial Heroku install document][2]

Beyond that, if you are feeling extra *extra* adventurous you can try to set up following components manually:

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

[1]: https://github.com/discourse/discourse/blob/master/docs/INSTALL-ubuntu.md
[2]: https://github.com/discourse/discourse/blob/master/docs/HEROKU.md

