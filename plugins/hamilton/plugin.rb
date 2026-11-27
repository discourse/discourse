# frozen_string_literal: true

# name: hamilton
# about: Hamilton plugin
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/hamilton

enabled_site_setting :hamilton_enabled

register_asset "stylesheets/common/hamilton.scss"

module ::Hamilton
  PLUGIN_NAME = "hamilton"
end

require_relative "lib/hamilton/engine"

after_initialize { add_admin_route "hamilton.title", "hamilton", use_new_show_route: true }
