# frozen_string_literal: true

# name: rhodes
# about: Rhodes product plugin for Discourse
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/rhodes-bot
# required_version: 2.7.0

enabled_site_setting :rhodes_enabled

module ::Rhodes
  PLUGIN_NAME = "rhodes"
end

require_relative "lib/rhodes/engine"
