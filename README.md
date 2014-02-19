# Heroku Discussion Forums

The Heroku Forums are a custom installation of [Discourse](https://github.com/discourse/discourse/) running on Heroku.

## Running Locally

If you wish to run Discussion locally, you will need to configure [Heroku OAuth to work for localhost over SSL](https://github.com/heroku/discussion/blob/master/HEROKU-LOCAL-OAUTH).

## Running on Heroku

Generic instructions for running Discourse on Heroku can be found in [./HEROKU](https://github.com/heroku/discussion/blob/master/HEROKU). For instructions specific to deploying to the `discussion` app on Heroku, see the Deploying section below.

## Tracking Discourse

Though there are merge conflicts that arise occasionally, it's usually a straight forward process to pull in changes from Discourse master.

1. Make sure you have an `upstream` remote: `$ git remote add upstream https://github.com/discourse/discourse.git`
1. Merge the latest master from origin: `$ git pull origin master`
1. Fetch the latest from upstream: `$ git fetch upstream`
1. Merge upstream/master to master: `$ git merge upstream/master`

Most times the merge will occur without conflicts and you can proceed with deployment. In the case of conflicts you will need to resolve them before proceeding.

Most conflicts occur in a consistent set of files, namely `Gemfile` and the various `Gemfile.lock` derivatives and any file heavily modified to run on Heroku such as `production.rb`, `redis.yml` and a few controllers and javascript files. The conflicts are often the result of an addition made in our fork, so resolving the conflict is a matter of ensuring the addition is preserved while still incorporating the new functionality from upstream.

Once all conflicts are resolved commit the merge: `$ git add . && git commit -m "Merge w/ upstream"` and deploy to staging.

## Deploying

The Discussion app uses [pipelines](https://devcenter.heroku.com/articles/labs-pipelines) to manage the release process. All deploys should go to `discussion-staging`, verified, and then promoted.

1. Deploy to staging: `$ git push staging master` (assumes a git remote named `staging` that points to the `discussion-staging` heroku repo)
1. Be sure to run any migrations: `$ heroku run rake db:migrate -r staging`
1. Verify basic functionality on https://discussion-staging.heroku.com/
1. If all checks out, push the repo to origin: `$ git push origin master` ...
1. ... and promote to production: `$ heroku pipeline:promote -r staging && heroku run rake db:migrate -r production`
