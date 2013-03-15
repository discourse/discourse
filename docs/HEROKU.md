# Basic Heroku deployment

This guide takes you through the steps for deploying Discourse to the [Heroku](http://www.heroku.com/) cloud application platform. If you're unfamiliar with Heroku, [read this first](https://devcenter.heroku.com/articles/quickstart). The basic deployment of Discourse requires several services that will cost you money. In addition to the [750 free Dyno hours](https://devcenter.heroku.com/articles/usage-and-billing) provided by Heroku, the application requires one additional process to be running for the Sidekiq queue ($34 monthly), and a Redis database plan that supports a minimum of 2 databases (average $10 monthly).

For details on how to reduce the monthly cost of your application, see the Advanced Heroku deployment instructions (coming soon).

## Download and configure Discourse

1. If you haven't already, download Discourse and create a new branch for your Heroku configuration.

        git clone git@github.com:discourse/discourse.git
        cd discourse
        git checkout -b heroku

2. Modify `production:` in the redis.yml file to use environment variables provided by Heroku and the Redis provider of your choice.

    *config/redis.yml*

        ...

        production:
          uri: <%= uri = URI.parse(ENV['OPENREDIS_URL']) if ENV['OPENREDIS_URL'] %>
          host: <%= uri.host if uri %>
          port: <%= uri.port if uri %>
          password: <%= uri.password if uri %>
          db: 0
          cache_db: 2

3. Comment out or delete `config/redis.yml` from .gitignore. We want to include redis.yml when we push to Heroku.

    *.gitignore*

        - config/redis.yml
        + # config/redis.yml

4. Commit your changes.

        git add .
        git commit -m "ready for Heroku"


## Configure Heroku

1. Create the heroku app. This automatically creates a git remote called heroku.

        heroku create your-app-name

2. Add a suitable Redis provider from [Heroku add-ons](https://addons.heroku.com/), (this service will cost you money).

        heroku addons:add openredis:micro

3. Add the [Heroku Scheduler](https://addons.heroku.com/scheduler) add-on, this saves us from running a separate clock process, reducing the cost of the app.

        heroku addons:add scheduler:standard

4. Generate a secret token in the terminal.

        rake secret

5. Push the secret to the stored heroku environment variables, this will now be available to your app globally.

        heroku config:add SECRET_TOKEN=<generated secret>

    ##### The next step is optional, as it is still in experimental 'labs' status with Heroku. You can choose to precompile your assets locally before deployment instead. If you do choose to precompile locally, remember to do it each time, before you deploy. For more information on this experimental feature see [Heroku Labs: user-env-compile](https://devcenter.heroku.com/articles/labs-user-env-compile).

6.  Make the environment variables available to heroku during deployment.

        heroku labs:enable user-env-compile -a your-app-name

    **Caveat:** If you should need to change or add environment variables for any reason, you will need to remove `user-env-compile`, then re-apply it after making the changes. This will then require you to make a commit, even if it is an empty commit, and then push to Heroku for the changes to be applied.

    If needed, you can remove the user-env-compile option with this command.

        heroku labs:disable user-env-compile -a your-app-name

7. Push your heroku branch to Heroku.

        git push heroku heroku:master

8. Migrate and seed the database.

        heroku run rake db:migrate db:seed_fu

    ##### You should now be able to visit your app at http://`<your-app-name>`.herokuapp.com

## Configure the deployed application

1. Log into the app, using your preferred auth provider.

2. Connect to the Heroku console to make the first user an Admin.

        heroku run console

3. Enter the following commands.

        u = User.first
        u.admin = true
        u.approved = true
        u.save

4. Provision the Heroku Scheduler

  This will allow Heroku Scheduler to cue up tasks rather than running a separate clock process.
  In the [Heroku dashboard](https://dashboard.heroku.com/apps), select your app, then click on **Heroku Scheduler Standard** under your Add-ons.

    Next, add a Job for each of the following:

    ##### TASK: `rake enqueue_digest_emails` FREQUENCY: `Daily` NEXT RUN: `06:00`

    ##### TASK: `rake category_stats` FREQUENCY: `Daily` NEXT RUN: `04:00`

    ##### TASK: `rake calculate_avg_time` FREQUENCY: `Every 10 minutes`

    ##### TASK: `rake feature_topics` FREQUENCY: `Every 10 minutes`

    ##### TASK: `rake calculate_score` FREQUENCY: `Every 10 minutes`

    ##### TASK: `rake calculate_view_counts` FREQUENCY: `Every 10 minutes`

    ##### TASK: `rake version_check` FREQUENCY: `Daily` NEXT RUN: `01:00`

5. Start Sidekiq

    In the [Heroku dashboard](https://dashboard.heroku.com/apps), select your app and you will see the separate processes that have been created for your application under Resources. You will only need to start the sidekiq process for your application to run properly. The clock process is covered by Heroku Scheduler, and you can even remove this from the Procfile before deploying if you so wish. The worker process has been generated as a Rails default and can be ignored. As you can see **the Sidekiq process costs $34 monthly** to run. If you want to reduce this cost, check out the Advanced Heroku deployment(coming soon).

    Click on the check-box next to the Sidekiq process and click Apply Changes

    ##### Your Discourse application should now be functional. However, you will still need to configure mail functionality and file storage for uploaded images. For some recommendations on doing this within Heroku, see the Advanced Heroku deployment guide (coming soon).

## Running the application locally

Using Foreman to start the application allows you to mimic the way the application is started on Heroku. It loads environment variables via the .env file and instantiates the application using the Procfile. In the .env sample file, we have set `RAILS_ENV='development'`, this makes the Rails environment variable available globally, and is required when starting this application using Foreman.

##### Create the .env file

  *.env*

      RAILS_ENV='development'



###Foreman commands:


##### Create the database

    bundle exec foreman run rake db:create

##### Migrate and seed the database

    bundle exec foreman run rake db:migrate db:seed_fu

##### Start the application using Foreman

    bundle exec foreman start

##### Use Rails console, with pry

    bundle exec foreman run rails console