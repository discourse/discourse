# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += %i[
  password
  pop3_polling_password
  api_key
  s3_secret_access_key
  twitter_consumer_secret
  facebook_app_secret
  github_client_secret
  second_factor_token
]
