# frozen_string_literal: true

# name: lovelace
# about: Configure a member onboarding checklist
# version: 0.0.1
# authors: Discourse Team
# url: https://github.com/discourse/discourse/tree/main/plugins/lovelace

enabled_site_setting :lovelace_enabled

register_asset "stylesheets/common/member-onboarding.scss"
add_admin_route "lovelace.title", "lovelace", use_new_show_route: true

module ::Lovelace
  PLUGIN_NAME = "lovelace"
end

require_relative "lib/lovelace/engine"
