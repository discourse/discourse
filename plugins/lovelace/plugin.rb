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

register_asset "stylesheets/common/checklist.scss"

register_asset "stylesheets/common/member-checklist.scss"
register_svg_icon "far-circle"
register_svg_icon "circle-check"

after_initialize do
  add_to_serializer(
    :current_user,
    :lovelace_member_checklist,
    include_condition: -> { SiteSetting.lovelace_enabled },
  ) { Lovelace::MemberChecklist.for_user(object) }
end
