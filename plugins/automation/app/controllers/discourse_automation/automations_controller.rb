# frozen_string_literal: true

module DiscourseAutomation
  class AutomationsController < ApplicationController
    requires_plugin PLUGIN_NAME
    before_action :ensure_admin

    def trigger
      automation = DiscourseAutomation::Automation.find(params[:id])
      if automation.trigger != DiscourseAutomation::Triggers::API_CALL &&
           !automation.triggerable&.settings&.fetch(
             DiscourseAutomation::Triggerable::MANUAL_TRIGGER_KEY,
             false,
           )
        raise Discourse::InvalidAccess
      end

      automation.trigger_in_background!(
        params.to_unsafe_h.merge(kind: DiscourseAutomation::Triggers::API_CALL),
      )
      render json: success_json
    end
  end
end
