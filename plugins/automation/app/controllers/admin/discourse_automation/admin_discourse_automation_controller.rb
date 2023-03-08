# frozen_string_literal: true

module DiscourseAutomation
  class AdminDiscourseAutomationController < ::ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME
    before_action :ensure_logged_in

    def index
    end

    def new
    end

    def edit
    end
  end
end
