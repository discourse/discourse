## Troubleshooting issues with Discourse environments

Are you having trouble setting up Discourse? Here are some basic things to check before
reaching out to the community for help:


1. Are you running Ruby 1.9.3 or later?

   Discourse is designed for Ruby 1.9.3 or later. You can check your version by typing 
   `ruby -v` and checking the response.


2. Are you on Postgres 9.1 or later with HSTORE enabled?

   You can check your postgres version by typing `psql --version`. To see if hstore is
   installed, open a session to postgres and type `\dx` and see if hstore is listed.


3. Have you run `bundle install`?

   We frequently update our dependencies to newer versions. It is a good idea to run
   `bundle install` every time you check out Discourse, especially if it's been a while.


3. Have you migrated your database?

   Our schema changes fairly frequently. After checking out the source code, you should 
   run `rake db:migrate`


4. Have you added the seed data?

   We depend on some basic seed data being present in the database. You should run 
   `rake db:seed_fu` to keep your database in sync.


5. Do the tests pass?

   If you are having other problems, it's useful to know if the test suite passes. You 
   can run it by first using `rake db:test:prepare` and then `rake spec`. If you 
   experience any failures, that's a bad sign! Our master branch should *always* pass 
   every test.

6. Have you updated host_names in your database.yml?

   If links in emails have localhost in them, then you are still using the default host_names
   value in database.yml.  Update it to use your site's host name(s).




