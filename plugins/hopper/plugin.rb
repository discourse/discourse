# frozen_string_literal: true

# name: hopper
# about: Hopper product plugin for Discourse
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/hopper

enabled_site_setting :hopper_enabled

module ::Hopper
  PLUGIN_NAME = "hopper"
end

require_relative "lib/hopper/engine"
