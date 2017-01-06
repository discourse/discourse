# Be sure to restart your server when you modify this file.
#
require_dependency 'discourse_cookie_store'

if Rails.env == "development" && SiteSetting.force_https
  STDERR.puts
  STDERR.puts "WARNING: force_https is enabled in dev"
  STDERR.puts "It is very unlikely you are running HTTPS in dev."
  STDERR.puts "Without HTTPS your session cookie will not work"
  STDERR.puts "Try: bin/rails c"
  STDERR.puts "SiteSetting.force_https = false"
  STDERR.puts
end

Discourse::Application.config.session_store(
  :discourse_cookie_store,
  key: '_forum_session',
  path: (Rails.application.config.relative_url_root.nil?) ? '/' : Rails.application.config.relative_url_root
)
