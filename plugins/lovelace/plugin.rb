# frozen_string_literal: true

# name: lovelace
# about: Lovelace plugin
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/lovelace-bot/tree/lovelace/plugins/lovelace
# required_version: 2.7.0

enabled_site_setting :lovelace_enabled

module ::Lovelace
  PLUGIN_NAME = "lovelace"
end

require_relative "lib/lovelace/engine"
