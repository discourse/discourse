# frozen_string_literal: true

module DiscourseAutomation
  class AutomationsController < ApplicationController
    before_action :ensure_admin

    def trigger
      automation = DiscourseAutomation::Automation.find(params[:id])
      automation.trigger!(params.merge(kind: DiscourseAutomation::Triggerable::ApiCall))
      render json: success_json
    end
  end
end
