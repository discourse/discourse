web: bundle exec rails server -p $PORT
sidekiq: bundle exec sidekiq -e $RAILS_ENV
custom_web: bundle exec thin start -C config/thin.yml -e $RACK_ENV -d