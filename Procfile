bundle exec thin start --socket /tmp/web_server.sock --pid /tmp/web_server.pid -C config/thin.yml -e $RACK_ENV -d
sidekiq: bundle exec sidekiq -e $RAILS_ENV