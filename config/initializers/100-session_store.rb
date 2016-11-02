# Be sure to restart your server when you modify this file.
#
require_dependency 'discourse_cookie_store'

Discourse::Application.config.session_store(
  :discourse_cookie_store,
  key: '_forum_session',
  path: (Rails.application.config.relative_url_root.nil?) ? '/' : Rails.application.config.relative_url_root
)

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Discourse::Application.config.session_store :active_record_store
