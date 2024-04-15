# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin Styleguide::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      if !current_user || !current_user.in_any_groups?(SiteSetting.styleguide_allowed_groups_map)
        raise Discourse::InvalidAccess.new
      end

      render "default/empty"
    end
  end
end
