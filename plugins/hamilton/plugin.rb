# frozen_string_literal: true

# name: hamilton
# about: Hamilton plugin
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/hamilton-bot/tree/hamilton/plugins/hamilton
# required_version: 2.7.0

enabled_site_setting :hamilton_enabled

module ::Hamilton
  PLUGIN_NAME = "hamilton"
end

require_relative "lib/hamilton/engine"
