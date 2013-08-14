# Discourse Migration Guide

## Install new server

Complete a fresh install of Discourse on the new server, following the official guide, except for the initial database population (rake db:migrate).

## Review old server

On old server, run `git status` and review changes to the tree. For example:

    # On branch master
    # Changes not staged for commit:
    #   (use "git add <file>..." to update what will be committed)
    #   (use "git checkout -- <file>..." to discard changes in working directory)
    #
    #	modified:   app/assets/javascripts/external/Markdown.Editor.js
    #	modified:   app/views/layouts/application.html.erb
    #	modified:   config/application.rb
    #
    # Untracked files:
    #   (use "git add <file>..." to include in what will be committed)
    #
    #	app/views/layouts/application.html.erb.bitnami
    #	config/environments/production.rb
    #	log/sidekiq.pid
    #	vendor/gems/active_model_serializers/
    #	vendor/gems/fast_blank/
    #	vendor/gems/message_bus/
    #	vendor/gems/redis-rack-cache/
    #	vendor/gems/sprockets/
    #	vendor/gems/vestal_versions/

### Review for changes

Review each of the changed files for changes that need to be manually moved over

* Ignore all files under vendor/gems
* Ignore files under log/

Check your config/environments/production.rb, config/discourse.pill,
config/database.yml (as per the upgrade instructions)

## Move DB

Take DB dump with:

    pg_dump --no-owner -U user_name -W database_name

Copy it over to the new server

Run as discourse user:

* createdb discourse_prod
* psql discourse_prod
 * \i discourse_dump_from_old_server.sql

On oldserver:

* rsync -avz -e ssh public newserver:public

    bundle install --without test --deployment
    RUBY_GC_MALLOC_LIMIT=90000000 RAILS_ENV=production rake db:migrate
    RUBY_GC_MALLOC_LIMIT=90000000 RAILS_ENV=production rake assets:precompile
    RUBY_GC_MALLOC_LIMIT=90000000 RAILS_ENV=production rake posts:rebake

Are you just testing your migration? Disable outgoing email by changing
`config/environments/production.rb` and adding the following below the mail
configuration:

    config.action_mailer.perform_deliveries = false
