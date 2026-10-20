# frozen_string_literal: true

# name: hopper
# about: Hopper plugin
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/hopper-bot/tree/hopper/plugins/hopper
# required_version: 2.7.0

enabled_site_setting :hopper_enabled

module ::Hopper
  PLUGIN_NAME = "hopper"
end

require_relative "lib/hopper/engine"
