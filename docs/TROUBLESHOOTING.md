## Troubleshooting issues with Discourse environments

Are you having trouble setting up Discourse? Here are some basic things to check before
reaching out to the community for help:


1. Are you running Ruby 2.0 or later?

   Discourse is designed for Ruby 2.0 or later. We recommend 2.0.0 p353 or later. You can check your version by typing
   `ruby -v` and checking the response.


2. Are you on Postgres 9.3 or later with HSTORE enabled?

   You can check your postgres version by typing `psql --version`. To see if hstore is
   installed, open a session to postgres and type `\dx` and see if hstore is listed.


3. Have you run `bundle install`?

   We frequently update our dependencies to newer versions. It is a good idea to run
   `bundle install` every time you check out Discourse, especially if it's been a while.

4. Did you run `bundle update`?

   Don't. Running `bundle update` will download gem versions that we haven't tested with.
   The Gemfile.lock has the gem versions that Discourse currently uses, so `bundle install`
   will work.  If you ran update, then you should uninstall the gems, run
   `git checkout -- Gemfile.lock` and then run `bundle install`.

5. Have you migrated your database?

   Our schema changes fairly frequently. After checking out the source code, you should
   run `rake db:migrate`

7. Do the tests pass?

   If you are having other problems, it's useful to know if the test suite passes. You
   can run it by first using `rake db:test:prepare` and then `rake spec`. If you
   experience any failures, that's a bad sign! Our master branch should *always* pass
   every test.

8. Have you updated host_names in your database.yml?

   If links in emails have localhost in them, then you are still using the default host_names
   value in database.yml.  Update it to use your site's host name(s).

9. Are you having problems bundling:

```
ArgumentError: invalid byte sequence in US-ASCII
An error occurred while installing active_model_serializers (0.7.0), and Bundler cannot continue.
Make sure that `gem install active_model_serializers -v '0.7.0'` succeeds before bundling.
```

   Try this in console:

```
$ export LANG="en_US.UTF-8"
$ export LC_ALL="en_US.UTF-8"
```

   And/or this in top of `Gemfile`:

```
if RUBY_VERSION =~ /1.9/
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8
end
```
