# frozen_string_literal: true

module DiscourseStyleguide
  class StyleguideController < ApplicationController
    requires_plugin DiscourseStyleguide::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      ensure_admin if SiteSetting.styleguide_admin_only

      render 'default/empty'
    end
  end
end
