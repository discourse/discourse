# frozen_string_literal: true

# name: lovelace
# about: Lovelace plugin
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/lovelace

enabled_site_setting :lovelace_enabled

module ::Lovelace
  PLUGIN_NAME = "lovelace"
end

require_relative "lib/lovelace/engine"
