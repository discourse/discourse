# Be sure to restart your server when you modify this file.

# Your secret key is used for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!

# Make sure your secret_key_base is kept private
# if you're sharing your code publicly.

# Definitely change this when you deploy to production. Ours is replaced by jenkins.
# This token is used to secure sessions, we don't mind shipping with one to ease test and debug,
# however, the stock one should never be used in production, people will be able to crack
# session cookies.
#
# Generate a new secret with "rake secret".  Copy the output of that command and paste it
# in your secret_token.rb as the value of Discourse::Application.config.secret_key_base:
#
# Discourse::Application.config.secret_key_base = "SET_SECRET_HERE"

# delete all lines below in production
if Rails.env.test? || Rails.env.development? || Rails.env == "profile"
  Discourse::Application.config.secret_key_base = '693210c6ee179286b332d0f6c8cca45b64c456a2b45513b7e4ef23163c817708b014ce85950660ef5db37979180cb4443d9a479608e4333780e7eb1ef63ccac8'
else
  raise "You must set a secret token in ENV['SECRET_TOKEN'] or in config/initializers/secret_token.rb" if ENV['SECRET_TOKEN'].blank?
  Discourse::Application.config.secret_key_base = ENV['SECRET_TOKEN']
end
