# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      allowed_group_ids = SiteSetting.styleguide_allowed_groups_map
      anonymous_allowed =
        allowed_group_ids.include?(Group::AUTO_GROUPS[:anonymous_users]) ||
          (
            !SiteSetting.granular_anonymous_and_logged_in_groups_permissions &&
              allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
          )

      return raise Discourse::NotFound if !current_user && !anonymous_allowed

      if current_user && !current_user.in_any_groups?(allowed_group_ids)
        return raise Discourse::NotFound
      end

      render "default/empty"
    end
  end
end
