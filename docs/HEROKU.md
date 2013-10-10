# Basic Heroku deployment

This guide takes you through the steps for deploying Discourse to the [Heroku](http://www.heroku.com/) cloud application platform. If you're unfamiliar with Heroku, [read this first](https://devcenter.heroku.com/articles/quickstart). The basic deployment of Discourse requires several services that will cost you money. In addition to the [750 free Dyno hours](https://devcenter.heroku.com/articles/usage-and-billing) provided by Heroku, the application requires one additional process to be running for the Sidekiq queue ($34 monthly), and a Redis database plan that supports a minimum of 2 databases (average $10 monthly).

For details on how to reduce the monthly cost of your application, see [Advanced Heroku deployment](#advanced-heroku-deployment).

## Download and configure Discourse

1. If you haven't already, download Discourse and create a new branch for your Heroku configuration.

        git clone git@github.com:discourse/discourse.git
        cd discourse
        git checkout -b heroku

2. Create a redis.yml file from the sample.

        cp config/redis.yml.sample config/redis.yml

3. Create a production.rb file from the sample.

        cp config/environments/production.rb.sample config/environments/production.rb

4. Comment out or delete the created files from .gitignore. We want to include them when we push to Heroku.

    *.gitignore*

    ```diff
    - config/redis.yml
    + # config/redis.yml
    ...
    - config/environments/production.rb
    + # config/environments/production.rb
    ```

5. Commit your changes.

        git add .
        git commit -m "ready for Heroku"


## Deploy to Heroku

1. Create the heroku app. This automatically creates a git remote called heroku.

        heroku create your-app-name

2. Add a suitable Redis provider from [Heroku add-ons](https://addons.heroku.com/), (this service will cost you money).

        heroku addons:add openredis:micro

3. Point the app at your redis provider's URL

        heroku config:get OPENREDIS_URL
        heroku config:set REDIS_PROVIDER_URL=<result of above command>

4. Run bundler

        bundle install

5. Generate a secret token in the terminal.

        rake secret

6. Push the secret to the stored heroku environment variables, this will now be available to your app globally.

        heroku config:add SECRET_TOKEN=<generated secret>

7. Precompile assets.

    There are two options for precompilation. Either precompile locally, **before each deploy** or enable [Heroku's experimental user-env-compile](https://devcenter.heroku.com/articles/labs-user-env-compile) feature and Heroku will precompile your assets for you.

    1. **Option 1:** Enable user-env-compile.

            heroku labs:enable user-env-compile

        **Caveat:** If you should need to change or add environment variables for any reason, you will need to remove `user-env-compile`, then re-apply it after making the changes. This will then require you to make a commit, even if it is an empty commit, and then push to Heroku for the changes to be applied.

        If needed, you can remove the user-env-compile option with this command.

            heroku labs:disable user-env-compile

    2. **Option 2:** Precompile locally.

            bundle exec rake assets:precompile

        **Notice:** We don't use Foreman to start precompilation, as this would precompile in the development environment. Instead, rake assets:precompile runs in the production environment by default, as it should.

        If Rails complains that the SECRET_TOKEN is not set, you can pass this to the environment by prefixing it to the rake method call.

            SECRET_TOKEN=5310bc16ef6ecfd0...  bundle exec rake assets:precompile

        **Tip:** OSX/Linux users can set/unset environment variables in their shell.

            # Set var
            export SECRET_TOKEN=5310bc16ef6ecfd0...
            # Unset var
            unset SECRET_TOKEN

        When precompiling locally make sure to alter the .gitignore file to allow the public/assets folder into version control.

        *.gitignore*

        ```diff
        - public/assets
        + # public/assets
        ```

        Also, you'll need to add a commit to get the precompiled assets onto Heroku.
            git add public/assets
            git push heroku heroku:master

8. Push your heroku branch to Heroku.

        git push heroku heroku:master

9. Migrate and seed the database.

        heroku run rake db:migrate db:seed_fu

    You should now be able to visit your app at `http://<your-app-name>.herokuapp.com`

## Configure the deployed application

1. Log into the app, using your preferred auth provider.

2. Connect to the Heroku console to make the first user an Admin.

        heroku run console

3. Enter the following commands.
```ruby
    u = User.first
    u.admin = true
    u.approved = true
    u.save
```

4. In Discourse admin settings, set `force_hostname` to your applications Heroku domain.

    This step is required for Discourse to properly form links sent with account confirmation emails and password resets. The auto detected application url would point to an Amazon AWS instance.

    Since you can't log in yet, you can set `force_hostname` in the console.
```ruby
   SiteSetting.create(:name => 'force_hostname', :data_type =>1, :value=>'yourappnamehere.herokuapp.com')
```

5. Start Sidekiq.

    In the [Heroku dashboard](https://dashboard.heroku.com/apps), select your app and you will see the separate processes that have been created for your application under Resources. You will only need to start the sidekiq process for your application to run properly. The worker process has been generated as a Rails default and can be ignored. As you can see **the Sidekiq process costs $34 monthly** to run. If you want to reduce this cost, check out [Advanced Heroku deployment](#advanced-heroku-deployment).

    Click on the check-box next to the Sidekiq process and click Apply Changes

    ##### Your Discourse application should now be functional. However, you will still need to [configure mail](#email) functionality and file storage for uploaded images. For some examples of doing this within Heroku, see [Heroku add-on examples](#heroku-add-on-examples).

## Running the application locally

Using Foreman to start the application allows you to mimic the way the application is started on Heroku. It loads environment variables via the .env file and instantiates the application using the Procfile. In the .env sample file, we have set `RAILS_ENV='development'`, this makes the Rails environment variable available globally, and is required when starting this application using Foreman.

Create a .env file from the sample.

    cp .env.sample .env

### Foreman commands:


##### Create the database

    foreman run rake db:create

##### Migrate and seed the database

    foreman run rake db:migrate db:seed_fu

##### Start the application using Foreman

    foreman run rails server

##### Use Rails console, with pry

    foreman run rails console

##### Prepare the test database

    foreman run rake db:test:prepare

##### Run tests

    foreman run rake autospec


# Heroku add-on examples

## Email

##### Mandrill example

1. Add the [Mandrill by MailChimp](https://devcenter.heroku.com/articles/mandrill) add-on from the [Heroku add-ons](https://addons.heroku.com/) page, or install from the command line using:

        heroku addons:add mandrill:starter

2. Configure the smtp settings in the production environment config file.

    *config/environments/production.rb*

    ```ruby
    - config.action_mailer.delivery_method = :sendmail
    - config.action_mailer.sendmail_settings = {arguments: '-i'}

    + config.action_mailer.delivery_method = :smtp
    + config.action_mailer.smtp_settings = {
    +     :port =>           '587',
    +     :address =>        'smtp.mandrillapp.com',
    +     :user_name =>      ENV['MANDRILL_USERNAME'],
    +     :password =>       ENV['MANDRILL_APIKEY'],
    +     :domain =>         'heroku.com',
    +     :authentication => :plain
    + }
    ```

## Load Testing

##### Blitz example

1. Add the [Blitz](https://addons.heroku.com/blitz) add-on from the [Heroku add-ons](https://addons.heroku.com/) page, or install from the command line using:

        heroku addons:add blitz:250

You can now run basic load tests against your instalation. Here's an example query with the rush of users scaling from 1 to 250 over 60 seconds. The timeout (-T) is set to 30 seconds, as after this Heroku will kill a process and return an error anyway.

    -p 1-250:60 -T 30000 http://YOUR-APP-NAME.herokuapp.com/

##### loader.io example

1. Add the [loader.io](https://addons.heroku.com/loaderio) add-on from the [Heroku add-ons](https://addons.heroku.com/) page, or install from the command line using:

        heroku addons:add loaderio:test

loader.io is still in beta, so you mileage may vary, but the tests are free for now.
They currently require you verify your domain. A simple way to do this is to add a hard coded static route to `config.routes.rb` using the loaderio verification key. You'll see the key the first time you try to run a load test.

*config/routes.rb*

```diff
Discourse::Application.routes.draw do
+ match "/loaderio-xxxxxxxxxxxxxxxxxxxx", :to => proc {|env| [200, {}, ["/loaderio-xxxxxxxxxxxxxxxxxxxx"]] }
  ...
end
```

# Advanced Heroku deployment

## Autoscaler

Adding the [Autoscaler Gem](https://github.com/JustinLove/autoscaler) can help you better manage the running cost of your application by scaling down the Sidekiq worker process when not in use. This could save up to $34 per month depending on your usage levels.

##### Whilst this Gem has the potential to save you money, it in no way guarantees it. Use of this Gem should be combined with careful monitoring of your applications processes and usage alerts where necessary.

1. Push your Heroku API key and app name to Heroku.

        heroku config:add HEROKU_API_KEY=<get your API key from acct settings> HEROKU_APP=<your app name>

2. Add the Autoscaler Gem to the Gemfile.

    *Gemfile*

    ```ruby
    gem 'autoscaler', require: false
    ```
3. Modify the Sidekiq config file to use the Autoscaler middleware in production.


    *config/initializers/sidekiq.rb*

    ```ruby
    sidekiq_redis = { url: $redis.url, namespace: 'sidekiq' }

    if Rails.env.production?

      require 'autoscaler/sidekiq'
      require 'autoscaler/heroku_scaler'

        Sidekiq.configure_server do |config|
          config.redis = sidekiq_redis
          config.server_middleware do |chain|
            chain.add(Autoscaler::Sidekiq::Server, Autoscaler::HerokuScaler.new('sidekiq'), 60)
          end
        end


        Sidekiq.configure_client do |config|
          config.redis = sidekiq_redis
          config.client_middleware do |chain|
            chain.add Autoscaler::Sidekiq::Client, 'default' => Autoscaler::HerokuScaler.new('sidekiq')
          end
        end

    else

      Sidekiq.configure_server { |config| config.redis = sidekiq_redis }
      Sidekiq.configure_client { |config| config.redis = sidekiq_redis }

    end

    ```

## S3 CDN

Heroku Cedar stack does not support Nginx as a caching layer, so you may want to host your static assets in a CDN so you're not hitting your rails app for every asset request.

This can be done simply using the [Asset Sync](https://github.com/rumblelabs/asset_sync) gem.

You'll need an Amazon S3 account set up with a bucket configured with your app name (appname-assets), and a separate user with write access to that bucket. You can create the new user in Account > Security Credentials. See [AWS best practices](http://docs.aws.amazon.com/IAM/latest/UserGuide/IAMBestPractices.html) for more details.

**Caveat:** This example relies on the app being deployed using the `heroku labs:enable user-env-compile` method detailed above. For instructions on manual compilation, please refer to the [Asset Sync](https://github.com/rumblelabs/asset_sync) gem readme.

1. Add the Asset Sync Gem to the Gemfile under assets.

    *Gemfile*

    ```diff
    group :assets do
      ...
    + gem 'asset_sync'
    end
    ```

2. Update production.rb to use the asset host.

    *config/environments/production.rb*

    ```diff
    - # config.action_controller.asset_host = "http://YOUR_CDN_HERE"
    + config.action_controller.asset_host = "//#{ENV['FOG_DIRECTORY']}.s3.amazonaws.com"
    ```

3. Get the access keys that were created for the new user and push the S3 configs to Heroku.

        heroku config:set FOG_PROVIDER=AWS AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=yyy FOG_DIRECTORY=appname-assets

4. Push the Gzip config setting to Heroku. This tells asset sync to upload Gzipped files where available.

        heroku config:add ASSET_SYNC_GZIP_COMPRESSION=true

Now commit your changes to Git and push to Heroku.

If you open Chrome's Inspector, click on Network and refresh the page, your assets should now be showing an amazonaws.com url. Please refer to the [Asset Sync](https://github.com/rumblelabs/asset_sync) gem readme for more configuration options, or to use another CDN such as AWS CloudFront for better performance.
