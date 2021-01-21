# frozen_string_literal: true

module DiscourseAutomation
  class AdminDiscourseAutomationTriggerablesController < ::ApplicationController
    def index
      if params[:automation_id].present?
        automation = DiscourseAutomation::Automation.find(params[:automation_id])
        scriptable = DiscourseAutomation::Scriptable.new(automation)
        triggerables = scriptable.triggerables
      else
        triggerables = DiscourseAutomation::Triggerable.all
      end

      triggerables.map! do |s|
        id = s.to_s.gsub(/^__triggerable_/, '')
        {
          id: id,
          name: I18n.t("discourse_automation.triggerables.#{id}.title"),
          description: I18n.t("discourse_automation.triggerables.#{id}.description"),
          doc: I18n.t("discourse_automation.triggerables.#{id}.doc"),
        }
      end

      render_json_dump(triggerables: triggerables)
    end
  end
end
