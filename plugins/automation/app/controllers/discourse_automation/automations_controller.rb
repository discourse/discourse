# frozen_string_literal: true

module DiscourseAutomation
  class AutomationsController < ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME
    before_action :ensure_admin

    def trigger
      automation = DiscourseAutomation::Automation.find(params[:id])
      automation.trigger!(params.merge(kind: DiscourseAutomation::Triggerable::API_CALL))
      render json: success_json
    end
  end
end
