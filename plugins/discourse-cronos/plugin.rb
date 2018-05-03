# name: discourse-cronos
# about: Display a date in your local timezone
# version: 0.1
# author: Joffrey Jaffeux

register_asset "javascripts/discourse-cronos.js"
register_asset "stylesheets/discourse-cronos.scss"
register_asset "moment.js", :vendored_core_pretty_text
register_asset "moment-timezone.js", :vendored_core_pretty_text

enabled_site_setting :discourse_cronos_enabled

load File.expand_path('../lib/discourse_cronos/engine.rb', __FILE__)
