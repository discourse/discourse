# frozen_string_literal: true

Discourse::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite.  You never need to work with it otherwise.  Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs.  Don't rely on the data there!
  config.cache_classes = true

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure static asset server for tests with Cache-Control for performance
  config.public_file_server.enabled = true

  # don't consider reqs local so we can properly handle exceptions like we do in prod
  config.consider_all_requests_local = false

  # disable caching
  config.action_controller.perform_caching = false

  # production has "show exceptions" on so we better have it
  # in test as well
  config.action_dispatch.show_exceptions = :all

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  # lower iteration count for test
  config.pbkdf2_iterations = 10

  config.assets.compile = true
  config.assets.digest = false

  config.active_record.verbose_query_logs = true
  config.active_record.query_log_tags_enabled = true

  config.active_record.query_log_tags = [
    :application,
    :controller,
    :action,
    {
      request_path: ->(context) { context[:controller]&.request&.path },
      thread_id: ->(context) { Thread.current.object_id },
    },
  ]

  # Catch missing translations during test runs.
  config.i18n.raise_on_missing_translations = true
  config.i18n.load_path += Dir[Rails.root.join("spec", "support", "locales", "**", "*.yml")]

  config.after_initialize do
    ActiveRecord::LogSubscriber.backtrace_cleaner.add_silencer do |line|
      line =~ %r{lib/freedom_patches}
    end
  end

  if ENV["RAILS_ENABLE_TEST_LOG"]
    config.logger = Logger.new(STDOUT)
    config.log_level =
      ENV["RAILS_TEST_LOG_LEVEL"].present? ? ENV["RAILS_TEST_LOG_LEVEL"].to_sym : :info
  else
    config.logger = Logger.new(nil)
    config.log_level = :fatal
  end

  if defined?(RspecErrorTracker)
    config.middleware.insert_after ActionDispatch::Flash, RspecErrorTracker
  end

  if ENV["CI"].present?
    config.to_prepare do
      ActiveSupport.on_load(:active_record_postgresqladapter) { self.create_unlogged_tables = true }
    end
  end
end
