# name: discourse-local-dates
# about: Display a date in your local timezone
# version: 0.1
# author: Joffrey Jaffeux

register_asset "javascripts/discourse-local-dates.js"
register_asset "stylesheets/discourse-local-dates.scss"
register_asset "moment.js", :vendored_core_pretty_text
register_asset "moment-timezone.js", :vendored_core_pretty_text

enabled_site_setting :discourse_local_dates_enabled

load File.expand_path('../lib/discourse_local_dates/engine.rb', __FILE__)
