# frozen_string_literal: true

# name: hamilton
# about: Hamilton plugin
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/hamilton

enabled_site_setting :hamilton_enabled

module ::Hamilton
  PLUGIN_NAME = "hamilton"
end

require_relative "lib/hamilton/engine"
