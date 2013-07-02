# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
# You can use `rake secret` to generate a secure secret key.

# Make sure your secret_key_base is kept private
# if you're sharing your code publicly.

# Definitely change this when you deploy to production. Ours is replaced by jenkins.
# This token is used to secure sessions, we don't mind shipping with one to ease test and debug,
#  however, the stock one should never be used in production, people will be able to crack
#  session cookies.
#
# Generate a new secret with "rake secret".  Copy the output of that command and paste it
# in your secret_token.rb as the value of Discourse::Application.config.secret_key_base:
#
# Discourse::Application.config.secret_key_base = "SET_SECRET_HERE"

if Rails.env.test? || Rails.env.development? || Rails.env == "profile"
  Discourse::Application.config.secret_key_base = 'a2f169f7baed0a3c950bfa5b4f3eca192a39abec12182950fe343cc12957d92b432abccdba9c433a5762c5fcc2785f4e4e6958cc139e8a11068d85ff9f3c5e13'
else
  raise "You must set a secret token in ENV['SECRET_TOKEN'] or in config/initializers/secret_token.rb" if ENV['SECRET_TOKEN'].blank?
  Discourse::Application.config.secret_key_base = ENV['SECRET_TOKEN']
end