# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      if !current_user &&
           !SiteSetting.styleguide_allowed_groups_map.include?(Group::AUTO_GROUPS[:everyone])
        return raise Discourse::NotFound
      end

      if current_user && !current_user.in_any_groups?(SiteSetting.styleguide_allowed_groups_map)
        return raise Discourse::NotFound
      end

      render "default/empty"
    end
  end
end
