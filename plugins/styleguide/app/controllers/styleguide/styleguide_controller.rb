# frozen_string_literal: true

module Styleguide
  class StyleguideController < ApplicationController
    requires_plugin Styleguide::PLUGIN_NAME
    skip_before_action :check_xhr

    def index
      ensure_admin if SiteSetting.styleguide_admin_only

      render "default/empty"
    end
  end
end
