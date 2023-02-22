# frozen_string_literal: true

module DiscourseAutomation
  class AdminDiscourseAutomationTriggerablesController < ::ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME

    def index
      if params[:automation_id].present?
        automation = DiscourseAutomation::Automation.find(params[:automation_id])
        scriptable = automation.scriptable
        triggerables = scriptable.triggerables
      else
        triggerables = DiscourseAutomation::Triggerable.all
      end

      triggerables =
        triggerables.map do |s|
          id = s.to_s.gsub(/^__triggerable_/, "")
          {
            id: id,
            name: I18n.t("discourse_automation.triggerables.#{id}.title"),
            description: I18n.t("discourse_automation.triggerables.#{id}.description", default: ""),
            doc: I18n.t("discourse_automation.triggerables.#{id}.doc", default: ""),
          }
        end

      render_json_dump(triggerables: triggerables)
    end
  end
end
