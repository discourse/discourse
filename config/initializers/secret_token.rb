
# Definitely change this when you deploy to production. Ours is replaced by jenkins.
# This token is used to secure sessions, we don't mind shipping with one to ease test and debug,
#  however, the stock one should never be used in production, people will be able to crack
#  session cookies.
#
# Generate a new secret with "rake secret".  Copy the output of that command and paste it
# in your secret_token.rb as the value of Discourse::Application.config.secret_token:
#
# Discourse::Application.config.secret_token = "SET_SECRET_HERE"

if Rails.env.test? || Rails.env.development? || Rails.env == "profile"
  Discourse::Application.config.secret_token = "a1257cf5649c1ac0a36825f6cabace2208aa7f7f5d4c6a425b6c412c9f9c3197c1e78cfa018910b45a5bf594ddde56e9b339e31300c242af38545cb9ad0fc14d"
else
  raise "You must set a secret token in ENV['SECRET_TOKEN'] or in config/initializers/secret_token.rb" if ENV['SECRET_TOKEN'].blank?
  Discourse::Application.config.secret_token = ENV['SECRET_TOKEN']
end

