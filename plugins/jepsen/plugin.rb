# frozen_string_literal: true

# name: jepsen
# about: Jepsen product plugin for Discourse
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/jepsen-bot
# required_version: 2.7.0

enabled_site_setting :jepsen_enabled

module ::Jepsen
  PLUGIN_NAME = "jepsen"
end

require_relative "lib/jepsen/engine"
