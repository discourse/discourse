# frozen_string_literal: true

module DiscourseAutomation
  class AutomationsController < ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME
    before_action :ensure_admin

    def trigger
      automation = DiscourseAutomation::Automation.find(params[:id])
      automation.trigger_in_background!(params.merge(kind: DiscourseAutomation::Triggers::API_CALL))
      render json: success_json
    end
  end
end
